import { globalIgnores } from "eslint/config";
import nextVitals from "eslint-config-next/core-web-vitals";
import nextTypescript from "eslint-config-next/typescript";
const config = [globalIgnores([".next/**", "node_modules/**", "out/**", "coverage/**"]), ...nextVitals, ...nextTypescript];
export default config;
