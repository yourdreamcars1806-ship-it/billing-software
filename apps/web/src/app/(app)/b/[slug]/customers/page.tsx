import { redirect } from "next/navigation";

/** Customers menu removed — billing pe name/mobile type karo */
export default async function CustomersPage({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;
  redirect(`/b/${slug}/billing`);
}
