import Image from "next/image";
import { Car } from "lucide-react";
import { LoginForm } from "@/features/auth/login-form";

export default function LoginPage() {
  return (
    <div className="flex min-h-screen flex-col bg-[#eef0f3]">
      <header className="border-b border-slate-200/90 bg-white">
        <div className="mx-auto flex h-14 max-w-5xl items-center px-4 sm:px-6">
          <div className="flex items-center gap-2.5">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              src="/images/billing-app-icon.png"
              alt="Billing Software"
              width={32}
              height={32}
              className="h-8 w-8 rounded-md object-cover"
            />
            <div className="leading-tight">
              <p className="text-sm font-semibold text-slate-900">
                Billing Software
              </p>
              <p className="text-[11px] text-slate-500">Secure staff login</p>
            </div>
          </div>
        </div>
      </header>

      <main className="mx-auto flex w-full max-w-5xl flex-1 items-center px-4 py-8 sm:px-6">
        {/* One joined panel */}
        <div className="grid w-full overflow-hidden rounded-2xl bg-white shadow-[0_2px_8px_rgba(15,23,42,0.04),0_24px_48px_-24px_rgba(15,23,42,0.22)] ring-1 ring-slate-200/80 lg:grid-cols-[1.05fr_0.95fr]">
          {/* LEFT — images joined */}
          <div className="flex flex-col border-b border-slate-100 lg:border-b-0 lg:border-r">
            {/* Clothing image */}
            <div className="relative min-h-[200px] flex-1 overflow-hidden border-b border-slate-100 bg-brand-soft lg:min-h-[240px]">
              <Image
                src="/images/login-clothing.png"
                alt="Drape & Dream clothing"
                fill
                className="object-cover"
                sizes="(max-width: 1024px) 100vw, 50vw"
                priority
              />
              <div className="absolute inset-0 bg-gradient-to-t from-black/55 via-black/10 to-transparent" />
              <div className="absolute bottom-0 left-0 right-0 flex items-end justify-between gap-3 p-4">
                <div className="flex items-center gap-2.5">
                  <span className="relative flex h-11 w-11 items-center justify-center overflow-hidden rounded-full bg-white shadow-sm">
                    <Image
                      src="/images/drape-and-dream-logo.png"
                      alt="Drape & Dream logo"
                      width={44}
                      height={44}
                      className="object-cover object-[center_12%]"
                    />
                  </span>
                  <div>
                    <p className="text-sm font-semibold text-white">
                      Drape & Dream
                    </p>
                    <p className="text-[11px] text-amber-50/90">
                      Clothing billing · Wear your story
                    </p>
                  </div>
                </div>
              </div>
            </div>

            {/* Cars image */}
            <div className="relative min-h-[200px] flex-1 overflow-hidden bg-blue-50 lg:min-h-[240px]">
              <Image
                src="/images/login-cars.png"
                alt="Your Dream Cars showroom"
                fill
                className="object-cover"
                sizes="(max-width: 1024px) 100vw, 50vw"
                priority
              />
              <div className="absolute inset-0 bg-gradient-to-t from-black/55 via-black/10 to-transparent" />
              <div className="absolute bottom-0 left-0 right-0 flex items-end justify-between gap-3 p-4">
                <div className="flex items-center gap-2.5">
                  <span className="flex h-9 w-9 items-center justify-center rounded-lg bg-blue-100 text-blue-800">
                    <Car className="h-4 w-4" />
                  </span>
                  <div>
                    <p className="text-sm font-semibold text-white">
                      Your Dream Cars
                    </p>
                    <p className="text-[11px] text-blue-100">
                      Car billing · Blue desk
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* RIGHT — login joined */}
          <div className="flex flex-col justify-center p-5 sm:p-7 lg:p-8">
            <div className="mb-5">
              <h1 className="text-lg font-semibold text-slate-900">Sign in</h1>
              <p className="mt-1 text-sm text-slate-500">
                Select business, then enter email & password.
              </p>
            </div>
            <LoginForm compact />
          </div>
        </div>
      </main>
    </div>
  );
}
