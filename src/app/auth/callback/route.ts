import { NextRequest,NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
export async function GET(request:NextRequest){
 const code=request.nextUrl.searchParams.get("code");const next=request.nextUrl.searchParams.get("next")||"/artist";
 if(code){const db=await createClient();if(db){const {error}=await db.auth.exchangeCodeForSession(code);if(!error){const safe=next.startsWith("/")&&!next.startsWith("//")?next:"/artist";return NextResponse.redirect(new URL(safe,request.url));}}}
 return NextResponse.redirect(new URL("/auth?error=Email%20verification%20could%20not%20be%20completed",request.url));
}
