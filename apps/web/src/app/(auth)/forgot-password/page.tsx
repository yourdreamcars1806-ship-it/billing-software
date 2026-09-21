import { redirect } from "next/navigation";

/** Old URL — forgot password now opens as a popup on /login */
export default function ForgotPasswordPage() {
  redirect("/login");
}
