import { motion, useScroll, useMotionValueEvent } from "framer-motion";
import { useState, useEffect } from "react";
import { Newspaper, Globe, Cpu, Layers, Moon, Sun } from "lucide-react";
import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";

function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

const GitHubIcon = ({ className }: { className?: string }) => (
  <svg
    role="img"
    viewBox="0 0 24 24"
    xmlns="http://www.w3.org/2000/svg"
    className={className}
    fill="currentColor"
  >
    <path d="M12 .297c-6.63 0-12 5.373-12 12 0 5.303 3.438 9.8 8.205 11.385.6.113.82-.258.82-.577 0-.285-.01-1.04-.015-2.04-3.338.724-4.042-1.61-4.042-1.61C4.422 18.07 3.633 17.7 3.633 17.7c-1.087-.744.084-.729.084-.729 1.205.084 1.838 1.236 1.838 1.236 1.07 1.835 2.809 1.305 3.495.998.108-.776.417-1.305.76-1.605-2.665-.3-5.466-1.332-5.466-5.93 0-1.31.465-2.38 1.235-3.22-.135-.303-.54-1.523.105-3.176 0 0 1.005-.322 3.3 1.23.96-.267 1.98-.399 3-.405 1.02.006 2.04.138 3 .405 2.28-1.552 3.285-1.23 3.285-1.23.645 1.653.24 2.873.12 3.176.765.84 1.23 1.91 1.23 3.22 0 4.61-2.805 5.625-5.475 5.92.42.36.81 1.096.81 2.22 0 1.606-.015 2.896-.015 3.286 0 .315.21.69.825.57C20.565 22.092 24 17.592 24 12.297c0-6.627-5.373-12-12-12" />
  </svg>
);

const Navbar = ({
  theme,
  toggleTheme,
}: {
  theme: string;
  toggleTheme: () => void;
}) => {
  const { scrollY } = useScroll();
  const [hidden, setHidden] = useState(false);

  useMotionValueEvent(scrollY, "change", (latest) => {
    const previous = scrollY.getPrevious() ?? 0;
    if (latest > previous && latest > 150) {
      setHidden(true);
    } else {
      setHidden(false);
    }
  });

  return (
    <motion.div
      variants={{
        visible: { y: 0 },
        hidden: { y: -120 },
      }}
      animate={hidden ? "hidden" : "visible"}
      transition={{ duration: 0.35, ease: "easeInOut" }}
      className="fixed top-8 left-0 right-0 z-50 flex justify-center px-6"
    >
      <nav className="flex items-center gap-4 px-6 py-3 glass rounded-full shadow-2xl border border-muted/20">
        <div className="flex items-center gap-3 px-4 mr-2 border-r border-muted/20">
          <img
            src="/app_icon.png"
            alt="Newron Logo"
            className="w-10 h-10 rounded-xl shadow-lg"
          />
          <span className="text-xl font-black tracking-tighter uppercase text-foreground">
            Newron
          </span>
        </div>

        <div className="flex items-center gap-2">
          {["Mission", "Models", "Features"].map((item) => (
            <a
              key={item}
              href={`#${item.toLowerCase()}`}
              className="px-6 py-3 text-sm font-bold text-muted hover:text-foreground rounded-full transition-all"
            >
              {item}
            </a>
          ))}
        </div>

        <div className="flex items-center gap-3 ml-2 pl-4 border-l border-muted/20">
          <button
            onClick={toggleTheme}
            className="p-2.5 text-muted hover:text-foreground rounded-full transition-colors hover:bg-black/5 dark:hover:bg-white/5"
          >
            {theme === "dark" ? (
              <Sun className="w-6 h-6" />
            ) : (
              <Moon className="w-6 h-6" />
            )}
          </button>
          <a
            href="https://github.com/Charlie284/newron"
            target="_blank"
            rel="noopener noreferrer"
            className="px-8 py-3 bg-[#c15f3c] text-white text-[13px] font-black rounded-full hover:bg-[#a14f32] transition-all uppercase tracking-[0.15em] shadow-xl shadow-[#c15f3c]/40 active:scale-95 flex items-center gap-2"
          >
            <GitHubIcon className="w-4 h-4" />
            GitHub
          </a>
        </div>
      </nav>
    </motion.div>
  );
};

const FeatureCard = ({
  title,
  description,
  icon: Icon,
  className,
  delay = 0,
}: any) => (
  <motion.div
    initial={{ opacity: 0, y: 20 }}
    whileInView={{ opacity: 1, y: 0 }}
    viewport={{ once: true }}
    transition={{ duration: 0.5, delay }}
    className={cn(
      "p-10 rounded-[3rem] glass flex flex-col gap-6 relative overflow-hidden group hover:shadow-2xl transition-all duration-500",
      className,
    )}
  >
    <div className="absolute inset-0 bg-gradient-to-br from-[#c15f3c]/5 to-transparent opacity-0 group-hover:opacity-100 transition-opacity" />

    <div className="relative z-10">
      <div className="w-16 h-14 rounded-2xl bg-[#c15f3c]/10 flex items-center justify-center mb-6">
        <Icon className="w-8 h-8 text-[#c15f3c]" />
      </div>
      <h3 className="text-3xl font-black tracking-tighter uppercase mb-2">
        {title}
      </h3>
      <p className="text-muted text-lg leading-relaxed font-medium">
        {description}
      </p>
    </div>
  </motion.div>
);

const App = () => {
  const [theme, setTheme] = useState(() => {
    if (typeof window !== "undefined") {
      return localStorage.getItem("theme") || "dark";
    }
    return "dark";
  });

  useEffect(() => {
    const root = window.document.documentElement;
    if (theme === "dark") {
      root.classList.add("dark");
    } else {
      root.classList.remove("dark");
    }
    localStorage.setItem("theme", theme);
  }, [theme]);

  const toggleTheme = () => {
    setTheme(theme === "light" ? "dark" : "light");
  };

  return (
    <div className="min-h-screen transition-colors duration-700 relative selection:bg-[#c15f3c]/30 selection:text-[#c15f3c]">
      <div className="fixed inset-0 grid-bg pointer-events-none" />
      <Navbar theme={theme} toggleTheme={toggleTheme} />

      {/* Hero Section */}
      <section className="relative pt-64 pb-48 px-12 overflow-hidden flex items-center min-h-[100vh]">
        <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[1400px] h-[1000px] glow-warm blur-[160px] rounded-full -z-10" />

        <div className="max-w-[1700px] mx-auto grid grid-cols-1 lg:grid-cols-[55%_45%] gap-0 items-center relative z-10 w-full">
          <motion.div
            initial={{ opacity: 0, scale: 0.9, x: -50 }}
            animate={{ opacity: 1, scale: 1, x: 0 }}
            transition={{ delay: 0.3, duration: 1.2, ease: [0.22, 1, 0.36, 1] }}
            className="relative flex justify-center lg:justify-start lg:-ml-20"
          >
            <div className="absolute -inset-20 glow-warm blur-[180px] rounded-full opacity-40 animate-pulse" />
            <motion.img
              animate={{ y: [0, -30, 0] }}
              transition={{ duration: 8, repeat: Infinity, ease: "easeInOut" }}
              src="/iphone_mockup.png"
              alt="Newron App"
              className="relative z-10 max-w-full lg:max-w-[1100px] drop-shadow-[40px_80px_120px_rgba(0,0,0,0.4)] dark:drop-shadow-[40px_80px_120px_rgba(0,0,0,0.7)]"
            />
          </motion.div>

          <motion.div
            initial={{ opacity: 0, x: 50 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ duration: 1 }}
            className="text-left flex flex-col items-start lg:pl-10"
          >
            <div className="mb-10 group cursor-default">
              <h1 className="text-[100px] md:text-[160px] font-black tracking-tighter leading-[0.6] uppercase text-foreground opacity-30 dark:opacity-20 transition-all duration-700 group-hover:opacity-40">
                See The
              </h1>
              <h1 className="text-[120px] md:text-[180px] font-black tracking-tighter leading-[0.8] uppercase text-[#c15f3c] drop-shadow-2xl">
                Gaps.
              </h1>
            </div>

            <p className="text-2xl md:text-4xl text-muted dark:text-foreground/90 max-w-2xl mb-16 leading-[1.3] font-bold tracking-tight">
              A personal news engine I built to escape the ads and see the
              reporting behind the headlines.{" "}
              <span className="text-[#c15f3c]">Free and Open Source.</span>
            </p>

            <div className="bg-black/20 dark:bg-black/40 backdrop-blur-3xl p-4 md:p-6 rounded-[3.5rem] shadow-2xl inline-flex items-center gap-4 border border-white/5 ml-2">
              <div className="flex flex-wrap items-center gap-4">
                <a
                  href="https://github.com/Charlie284/newron"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="flex items-center gap-4 bg-[#c15f3c] text-white px-8 md:px-10 py-5 rounded-[2rem] hover:scale-105 transition-all duration-300 shadow-2xl shadow-[#c15f3c]/40 active:scale-95"
                >
                  <GitHubIcon className="w-8 h-8" />
                  <div className="text-left">
                    <p className="text-[10px] uppercase font-black opacity-70 tracking-widest leading-none mb-1">
                      Checkout
                    </p>
                    <p className="text-3xl font-black leading-none">Repo</p>
                  </div>
                </a>

                <a
                  href="http://app.newron.clh.lol/"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="flex items-center gap-4 bg-white/5 dark:bg-white/[0.03] text-foreground px-8 md:px-10 py-5 rounded-[2rem] hover:bg-white/10 transition-all duration-300 border border-white/10 active:scale-95"
                >
                  <div className="text-left">
                    <p className="text-[10px] uppercase font-black opacity-70 tracking-widest leading-none mb-1">
                      Open
                    </p>
                    <p className="text-3xl font-black leading-none">Web App</p>
                  </div>
                </a>
              </div>
            </div>
          </motion.div>
        </div>
      </section>

      {/* Why we built it */}
      <section id="mission" className="py-64 px-12 relative overflow-hidden">
        <div className="max-w-[1400px] mx-auto text-center relative z-10">
          <motion.div
            initial={{ opacity: 0, y: 30 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 1 }}
          >
            <h2 className="text-sm font-black uppercase tracking-[0.4em] text-[#c15f3c] mb-12">
              The Mission
            </h2>
            <h3 className="text-4xl md:text-7xl font-black tracking-tighter uppercase leading-[0.95] mb-16 text-foreground">
              Built because I <br />{" "}
              <span className="opacity-40">didn't have the time.</span>
            </h3>
            <div className="max-w-4xl mx-auto space-y-10">
              <p className="text-2xl md:text-4xl text-muted font-bold leading-tight tracking-tight">
                Hi, I'm Charlie. I wanted my daily news brief without the
                constant ads, trackers, and the "doom-scroll" distractions of
                modern apps.
              </p>

              <p className="text-2xl md:text-4xl text-foreground font-black leading-tight tracking-tight">
                So we built an aggregator that respects your time researching
                the gaps so you don't have to.
              </p>
            </div>
          </motion.div>
        </div>
        <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-full h-full glow-warm blur-[160px] opacity-20 -z-10" />
      </section>

      {/* Scrolling Models Marquee */}
      <section
        id="models"
        className="py-24 border-y border-muted/10 bg-black/5 dark:bg-white/[0.02] overflow-hidden"
      >
        <div className="max-w-7xl mx-auto px-12 mb-12">
          <p className="text-center text-[11px] font-black tracking-[0.3em] uppercase text-muted">
            Choose your intelligence
          </p>
        </div>

        <div className="flex relative items-center">
          <motion.div
            animate={{ x: ["0%", "-50%"] }}
            transition={{ duration: 40, repeat: Infinity, ease: "linear" }}
            className="flex gap-12 items-center whitespace-nowrap min-w-max"
          >
            {[
              "OpenRouter",
              "Gemma 4 31B",
              "Nemotron",
              "MiniMax",
              "Llama 3",
              "Mistral Large",
              "GPT-4o",
              "Claude 3.5",
              "Gemini Pro",
              "OpenRouter",
              "Gemma 4 31B",
              "Nemotron",
              "MiniMax",
              "Llama 3",
              "Mistral Large",
              "GPT-4o",
              "Claude 3.5",
              "Gemini Pro",
            ].map((model, i) => (
              <div
                key={i}
                className="px-10 py-4 rounded-3xl glass border border-muted/10 text-2xl font-black tracking-tighter uppercase text-muted/60 hover:text-foreground hover:scale-105 transition-all cursor-default"
              >
                {model}
              </div>
            ))}
          </motion.div>
        </div>
      </section>

      {/* Features */}
      <section id="features" className="py-64 px-12 relative z-10">
        <div id="sources" className="absolute top-0 left-0" />
        <div className="max-w-[1700px] mx-auto">
          <div className="text-left mb-40">
            <h2 className="text-6xl md:text-[10rem] font-black mb-10 tracking-tighter uppercase leading-[0.8] text-foreground">
              How it <br /> <span className="text-[#c15f3c]">Works.</span>
            </h2>
            <p className="text-muted text-3xl max-w-4xl font-bold leading-relaxed tracking-tight">
              Newron maps the reporting gaps and visualizes the lean of every
              headline. You get the full picture and the underlying perspective
              without the noise.
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-12 gap-12">
            <FeatureCard
              className="md:col-span-4"
              icon={Globe}
              title="70+ Sources"
              description="Direct access to global news organizations via high-speed encrypted RSS protocols."
              delay={0.2}
            />

            <FeatureCard
              className="md:col-span-4"
              icon={Layers}
              title="Absolute Privacy"
              description="Zero algorithms, zero tracking. Your research and data remain strictly in your control."
              delay={0.3}
            />

            <FeatureCard
              className="md:col-span-4"
              icon={Cpu}
              title="Built with Flutter"
              description="Native performance on every screen. Newron runs seamlessly on Android, iOS, Web, and Desktop."
              delay={0.4}
            />

            <FeatureCard
              className="md:col-span-12 mt-12"
              icon={Newspaper}
              title="Source Protocol"
              description="Consolidated from global news organizations, independent journals, and niche tech publications for a truly broad perspective."
              delay={0.4}
            />
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="border-t border-muted/20 py-48 px-12 relative z-10 bg-black/5 dark:bg-white/[0.02]">
        <div className="max-w-[1700px] mx-auto flex flex-col md:flex-row justify-between items-start gap-40">
          <div className="flex flex-col gap-10 max-w-lg">
            <div className="flex items-center gap-4">
              <img
                src="/app_icon.png"
                alt="Newron"
                className="w-16 h-16 rounded-3xl shadow-2xl"
              />
              <span className="text-5xl font-black tracking-tighter uppercase text-foreground">
                Newron
              </span>
            </div>
            <p className="text-muted text-2xl leading-relaxed font-bold tracking-tight">
              Redefining news aggregation with open intelligence. <br />
              Created by{" "}
              <a
                href="https://clh.lol"
                target="_blank"
                rel="noopener noreferrer"
                className="text-[#c15f3c] hover:underline"
              >
                Charlie
              </a>
              .
            </p>
            <div className="flex items-center gap-12 text-muted/60">
              <a
                href="https://github.com/Charlie284/newron"
                target="_blank"
                rel="noopener noreferrer"
                className="hover:text-foreground transition-all scale-[1.75]"
              >
                <GitHubIcon className="w-8 h-8" />
              </a>
              <Globe className="w-8 h-8 hover:text-foreground cursor-pointer transition-all scale-[1.75]" />
            </div>
          </div>
        </div>
        <div className="max-w-[1700px] mx-auto mt-64 pt-16 border-t border-muted/20">
          <p className="text-muted/40 text-sm font-black uppercase tracking-[0.5em]">
            © 2026 Newron. MIT Licensed.
          </p>
        </div>
      </footer>
    </div>
  );
};

export default App;
