import type { Metadata } from "next";
import "./globals.css";
export const metadata: Metadata = { metadataBase: new URL(process.env.NEXT_PUBLIC_SITE_URL || "http://localhost:3000"), title: { default: "Sauti — Find your next favourite", template: "%s · Sauti" }, description: "Discover the sounds shaping Africa and the world. Artist-led music discovery, country charts and official video links.", openGraph: { title: "Sauti — Find your next favourite", description: "Music discovery with African roots and a global ear.", type: "website" } };
export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) { return <html lang="en"><body>{children}</body></html>; }
