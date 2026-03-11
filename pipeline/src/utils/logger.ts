const COLORS = {
  reset: "\x1b[0m",
  dim: "\x1b[2m",
  red: "\x1b[31m",
  green: "\x1b[32m",
  yellow: "\x1b[33m",
  blue: "\x1b[34m",
  cyan: "\x1b[36m",
};

function timestamp(): string {
  return new Date().toISOString().replace("T", " ").slice(0, 19);
}

export const log = {
  info(source: string, msg: string) {
    console.log(
      `${COLORS.dim}${timestamp()}${COLORS.reset} ${COLORS.blue}[${source}]${COLORS.reset} ${msg}`
    );
  },
  success(source: string, msg: string) {
    console.log(
      `${COLORS.dim}${timestamp()}${COLORS.reset} ${COLORS.green}[${source}]${COLORS.reset} ${msg}`
    );
  },
  warn(source: string, msg: string) {
    console.warn(
      `${COLORS.dim}${timestamp()}${COLORS.reset} ${COLORS.yellow}[${source}]${COLORS.reset} ${msg}`
    );
  },
  error(source: string, msg: string, err?: unknown) {
    console.error(
      `${COLORS.dim}${timestamp()}${COLORS.reset} ${COLORS.red}[${source}]${COLORS.reset} ${msg}`
    );
    if (err instanceof Error) {
      console.error(`  ${COLORS.dim}${err.message}${COLORS.reset}`);
    }
  },
  divider() {
    console.log(`${COLORS.dim}${"─".repeat(60)}${COLORS.reset}`);
  },
};
