import { NextRequest,NextResponse } from "next/server";
import { z } from "zod";
import { createClient } from "@/lib/supabase/server";
import { one,rows,type Relation } from "@/lib/supabase/relations";
const filterSchema=z.object({q:z.string().trim().max(100).optional(),country:z.enum(["South Sudan","Kenya","Uganda","Tanzania","Nigeria","Ghana"]).optional(),genre:z.string().trim().max(50).optional()});
const countryIds:Record<string,string>={"South Sudan":"SS",Kenya:"KE",Uganda:"UG",Tanzania:"TZ",Nigeria:"NG",Ghana:"GH"};
export async function GET(request:NextRequest){
 const parsed=filterSchema.safeParse({q:request.nextUrl.searchParams.get("q")||undefined,country:request.nextUrl.searchParams.get("country")||undefined,genre:request.nextUrl.searchParams.get("genre")||undefined});if(!parsed.success)return NextResponse.json({error:"Invalid discovery filters."},{status:400});
 const db=await createClient();if(!db)return NextResponse.json({configured:false,tracks:[],artists:[],message:"Supabase catalog is not configured. Showing clearly labelled sample data."});
 let songsQuery=db.from("songs").select("id,title,release_date,country_id,artists(name,slug),genres(name),countries(name),song_sources(provider,provider_id,external_url,is_embeddable)").eq("status","approved").order("release_date",{ascending:false,nullsFirst:false}).limit(100);
 let artistsQuery=db.from("artists").select("name,slug,country_id,countries(name)").eq("status","approved").order("name").limit(100);
 if(parsed.data.country){songsQuery=songsQuery.eq("country_id",countryIds[parsed.data.country]);artistsQuery=artistsQuery.eq("country_id",countryIds[parsed.data.country]);}
 if(parsed.data.genre)songsQuery=songsQuery.eq("genres.name",parsed.data.genre);
 const [{data:songs,error:songsError},{data:artists,error:artistsError}]=await Promise.all([songsQuery,artistsQuery]);if(songsError||artistsError)return NextResponse.json({error:"The music catalog could not be loaded."},{status:503});
 type SongRow={id:string;title:string;release_date:string|null;country_id:string|null;artists:Relation<{name:string;slug:string}>;genres:Relation<{name:string}>;countries:Relation<{name:string}>;song_sources:Array<{provider:string;provider_id:string|null;external_url:string|null;is_embeddable:boolean}>};type ArtistRow={name:string;slug:string;country_id:string|null;countries:Relation<{name:string}>};const colors=["gold","blue","rose","violet","green","orange"];
 const tracks=rows<SongRow>(songs).map((row,index)=>{const artist=one(row.artists);const genre=one(row.genres);const country=one(row.countries);return{id:row.id,title:row.title,artist:artist?.name||"Artist",artistSlug:artist?.slug||null,country:country?.name||row.country_id||"Africa",genre:genre?.name||"African music",color:colors[index%colors.length],note:row.release_date?"NEW RELEASE":"SAUTI DISCOVERY",source:row.song_sources?.find(s=>s.provider==="licensed_audio"&&s.is_embeddable)||row.song_sources?.find(s=>s.provider==="youtube"&&s.is_embeddable)||row.song_sources?.find(s=>s.provider==="official_link")||null};});
 const q=parsed.data.q?.toLowerCase();const selected=q?tracks.filter(t=>`${t.title} ${t.artist} ${t.genre} ${t.country}`.toLowerCase().includes(q)):tracks;
 const artistCards=rows<ArtistRow>(artists).map((a,i)=>({name:a.name,slug:a.slug,place:one(a.countries)?.name||a.country_id||"Africa",color:colors[i%colors.length],initials:a.name.split(/\s+/).map(x=>x[0]).join("").slice(0,2).toUpperCase()})).filter(a=>!q||a.name.toLowerCase().includes(q));
 return NextResponse.json({configured:true,tracks:selected,artists:artistCards});
}

