import Image from "next/image";
import logo from "../../public/next.svg";
import styles from "./page.module.css";

export default function Home() {
  return (
    <div className={styles.page}>
      <main className={styles.main}>
        <Image className={styles.logo} src={logo} alt="" priority />
        <div className={styles.intro}>
          <h1>To get started, edit the page.tsx file.</h1>
          <p>
            This <span>{process.env.NEXT_PUBLIC_APP_NAME}</span> is a sample for
            building a Next.js development environment using Nix, direnv and
            dotenvx.
          </p>
        </div>
      </main>
    </div>
  );
}
