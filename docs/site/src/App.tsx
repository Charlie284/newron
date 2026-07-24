import { useEffect, useState } from "react";
import {
  BookOpenCheck,
  Bot,
  ExternalLink,
  Globe2,
  Moon,
  Newspaper,
  ShieldCheck,
  Sun,
  type LucideIcon,
} from "lucide-react";

const GitHubIcon = ({ className }: { className?: string }) => (
  <svg
    aria-hidden="true"
    viewBox="0 0 24 24"
    xmlns="http://www.w3.org/2000/svg"
    className={className}
    fill="currentColor"
  >
    <path d="M12 .297c-6.63 0-12 5.373-12 12 0 5.303 3.438 9.8 8.205 11.385.6.113.82-.258.82-.577 0-.285-.01-1.04-.015-2.04-3.338.724-4.042-1.61-4.042-1.61C4.422 18.07 3.633 17.7 3.633 17.7c-1.087-.744.084-.729.084-.729 1.205.084 1.838 1.236 1.838 1.236 1.07 1.835 2.809 1.305 3.495.998.108-.776.417-1.305.76-1.605-2.665-.3-5.466-1.332-5.466-5.93 0-1.31.465-2.38 1.235-3.22-.135-.303-.54-1.523.105-3.176 0 0 1.005-.322 3.3 1.23.96-.267 1.98-.399 3-.405 1.02.006 2.04.138 3 .405 2.28-1.552 3.285-1.23 3.285-1.23.645 1.653.24 2.873.12 3.176.765.84 1.23 1.91 1.23 3.22 0 4.61-2.805 5.625-5.475 5.92.42.36.81 1.096.81 2.22 0 1.606-.015 2.896-.015 3.286 0 .315.21.69.825.57C20.565 22.092 24 17.592 24 12.297c0-6.627-5.373-12-12-12" />
  </svg>
);

type FeatureProps = {
  icon: LucideIcon;
  title: string;
  description: string;
};

function Feature({ icon: Icon, title, description }: FeatureProps) {
  return (
    <article className="feature">
      <Icon aria-hidden="true" />
      <h3>{title}</h3>
      <p>{description}</p>
    </article>
  );
}

function App() {
  const [dark, setDark] = useState(() => {
    const stored = window.localStorage.getItem("newron-theme");
    return stored
      ? stored === "dark"
      : window.matchMedia("(prefers-color-scheme: dark)").matches;
  });

  useEffect(() => {
    document.documentElement.classList.toggle("dark", dark);
    window.localStorage.setItem("newron-theme", dark ? "dark" : "light");
  }, [dark]);

  return (
    <>
      <a className="skip-link" href="#main">
        Skip to main content
      </a>
      <header className="site-header">
        <nav aria-label="Primary navigation" className="nav-shell">
          <a href="#top" className="brand" aria-label="Newron home">
            <img src="/app_icon.png" width="40" height="40" alt="" />
            <span>Newron</span>
          </a>
          <div className="nav-links">
            <a href="#approach">Approach</a>
            <a href="#features">Features</a>
            <a href="#privacy">Privacy</a>
          </div>
          <button
            type="button"
            className="icon-button"
            onClick={() => setDark((value) => !value)}
            aria-label={dark ? "Use light theme" : "Use dark theme"}
            title={dark ? "Use light theme" : "Use dark theme"}
          >
            {dark ? <Sun aria-hidden="true" /> : <Moon aria-hidden="true" />}
          </button>
          <a
            className="nav-github"
            href="https://github.com/Charlie284/newron"
            target="_blank"
            rel="noreferrer"
          >
            <GitHubIcon className="github-icon" />
            <span>Source</span>
          </a>
        </nav>
      </header>

      <main id="main">
        <section id="top" className="hero">
          <div className="hero-copy">
            <p className="kicker">Open-source news reader</p>
            <h1>See the reporting. Ask for synthesis.</h1>
            <p className="hero-lede">
              Newron ranks timestamped stories from a catalog of 70+ RSS feeds,
              links every original, and keeps AI off until you explicitly ask
              for a source-grounded brief.
            </p>
            <div className="hero-actions">
              <a
                className="primary-action"
                href="https://app.newron.clh.lol/"
                target="_blank"
                rel="noreferrer"
              >
                Open web app <ExternalLink aria-hidden="true" />
              </a>
              <a
                className="secondary-action"
                href="https://github.com/Charlie284/newron"
                target="_blank"
                rel="noreferrer"
              >
                View source <GitHubIcon className="github-icon" />
              </a>
            </div>
            <p className="hero-note">
              AI output can be wrong. Newron shows its cited inputs so you can
              verify important claims in the original reporting.
            </p>
          </div>
          <div className="hero-visual">
            <div className="visual-backdrop" aria-hidden="true" />
            <img
              src="/iphone_mockup.webp"
              width="1600"
              height="1200"
              fetchPriority="high"
              alt="Newron reader showing a briefing beside linked source coverage"
            />
          </div>
        </section>

        <section id="approach" className="statement section-shell">
          <p className="kicker">Built for verification</p>
          <h2>A reader first. An AI tool second.</h2>
          <p>
            Each refresh contacts a bounded set of feeds, parses publication
            dates, removes duplicates, and balances publishers before showing
            coverage. You can read every original without generating an AI
            request.
          </p>
        </section>

        <section id="features" className="features-section section-shell">
          <div className="section-heading">
            <p className="kicker">What it does</p>
            <h2>Useful defaults, visible limits.</h2>
          </div>
          <div className="feature-grid">
            <Feature
              icon={Globe2}
              title="Broad source catalog"
              description="A 70+ feed catalog spans global, local, business, science, technology, policy, health, and sports reporting. A refresh selects at most 12 feeds."
            />
            <Feature
              icon={Newspaper}
              title="Dated, linked coverage"
              description="Stories are ranked by supplied publication time, de-duplicated, diversified by publisher, and always link back to an HTTPS original."
            />
            <Feature
              icon={Bot}
              title="Opt-in AI synthesis"
              description="AI runs only after you choose it. The gateway accepts fixed briefing tasks, excludes web search, and requires citations to displayed article IDs."
            />
            <Feature
              icon={BookOpenCheck}
              title="Fact-check context"
              description="The fact-check view compares the displayed AI brief with the same supplied reporting and clearly states that this is not independent proof."
            />
          </div>
        </section>

        <section id="privacy" className="privacy-section section-shell">
          <div>
            <ShieldCheck aria-hidden="true" className="privacy-icon" />
            <p className="kicker">Privacy, stated precisely</p>
            <h2>No account. No startup AI call.</h2>
          </div>
          <div className="privacy-copy">
            <p>
              Briefings are cached on your device. When you choose an AI
              action, Newron sends the displayed article metadata and your task
              to its gateway and selected model provider. The marketing site
              includes no analytics or advertising scripts.
            </p>
            <p>
              The code is MIT licensed, so these claims can be inspected rather
              than taken on faith.
            </p>
          </div>
        </section>

        <section className="cta section-shell">
          <div>
            <p className="kicker">Flutter, in the open</p>
            <h2>Inspect it. Run it. Improve it.</h2>
          </div>
          <a
            className="primary-action"
            href="https://github.com/Charlie284/newron"
            target="_blank"
            rel="noreferrer"
          >
            Browse the repository <ExternalLink aria-hidden="true" />
          </a>
        </section>
      </main>

      <footer className="site-footer section-shell">
        <div className="brand footer-brand">
          <img src="/app_icon.png" width="40" height="40" alt="" />
          <span>Newron</span>
        </div>
        <p>Created by Charlie Harper · MIT licensed · © 2026</p>
        <div className="footer-links">
          <a
            href="https://github.com/Charlie284/newron"
            target="_blank"
            rel="noreferrer"
            aria-label="Newron source code on GitHub"
          >
            <GitHubIcon className="github-icon" />
          </a>
          <a
            href="https://app.newron.clh.lol/"
            target="_blank"
            rel="noreferrer"
            aria-label="Open the Newron web app"
          >
            <Globe2 aria-hidden="true" />
          </a>
        </div>
      </footer>
    </>
  );
}

export default App;
