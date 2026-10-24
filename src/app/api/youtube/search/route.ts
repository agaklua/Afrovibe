import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";
const schema=z.object({q:z.string().trim().min(2).max(100),pageToken:z.string().max(200).optional()});
export async function GET(request:NextRequest){
 const parsed=schema.safeParse({q:request.nextUrl.searchParams.get("q"),pageToken:request.nextUrl.searchParams.get("pageToken")||undefined});
 if(!parsed.success)return NextResponse.json({error:"Enter a search of 2–100 characters."},{status:400});
 const key=process.env.YOUTUBE_API_KEY;
 if(!key)return NextResponse.json({configured:false,message:"YouTube search is not configured yet. Add YOUTUBE_API_KEY on the server to enable official video results.",items:[]});
 try{
  const url=new URL("https://www.googleapis.com/youtube/v3/search");url.search=new URLSearchParams({part:"snippet",type:"video",videoEmbeddable:"true",maxResults:"12",q:`${parsed.data.q} music`,key,...(parsed.data.pageToken?{pageToken:parsed.data.pageToken}:{})}).toString();
  const response=await fetch(url,{next:{revalidate:300}});
  if(!response.ok)return NextResponse.json({error:response.status===403?"YouTube search is unavailable. Check API access and quota.":"Video search is temporarily unavailable.",items:[]},{status:response.status===403?503:502});
  const data=await response.json();
  return NextResponse.json({configured:true,items:(data.items||[]).map((item:{id:{videoId:string};snippet:{title:string;channelTitle:string;thumbnails:{medium?:{url:string};default?:{url:string}};publishedAt:string}})=>({videoId:item.id.videoId,title:item.snippet.title,channelTitle:item.snippet.channelTitle,thumbnail:item.snippet.thumbnails.medium?.url||item.snippet.thumbnails.default?.url,publishedAt:item.snippet.publishedAt,videoUrl:`https://www.youtube.com/watch?v=${encodeURIComponent(item.id.videoId)}`})),nextPageToken:data.nextPageToken||null});
 }catch{return NextResponse.json({error:"Could not reach YouTube. Try again shortly.",items:[]},{status:502});}
}
