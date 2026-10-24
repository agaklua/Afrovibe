import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
export async function GET(){const db=await createClient();if(!db)return NextResponse.json({configured:false,items:[]});const {data,error}=await db.from("music_events").select("id,title,country_id,venue,starts_at,external_url,sponsored,countries(name)").eq("status","approved").gte("starts_at",new Date().toISOString()).order("starts_at").limit(8);if(error)return NextResponse.json({error:"Upcoming events are unavailable."},{status:503});return NextResponse.json({configured:true,items:data||[]});}
