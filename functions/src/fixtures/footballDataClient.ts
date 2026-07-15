const DEFAULT_BASE_URL = "https://api.football-data.org/v4";

export interface FootballDataRateLimit {
  readonly remainingThisMinute: number | null;
  readonly resetAfterSeconds: number | null;
  readonly retryAfterSeconds: number | null;
}

export interface FootballDataResponse<T> {
  readonly data: T;
  readonly rateLimit: FootballDataRateLimit;
}

export interface FootballDataClientOptions {
  readonly token: string;
  readonly fetch?: typeof fetch;
  readonly baseUrl?: string;
  readonly timeoutMilliseconds?: number;
  readonly maximumAttempts?: number;
  readonly now?: () => number;
  readonly sleep?: (milliseconds: number) => Promise<void>;
}

export class FootballDataProviderError extends Error {
  constructor(
    public readonly status: number,
    public readonly retryable: boolean,
    public readonly retryAfterSeconds: number | null,
  ) {
    super(status === 429 ? "FOOTBALL_PROVIDER_RATE_LIMITED" : "FOOTBALL_PROVIDER_UNAVAILABLE");
  }
}

/** Server-only v4 client. The credential must come from Secret Manager. */
export class FootballDataClient {
  private readonly fetchImplementation: typeof fetch;
  private readonly baseUrl: string;
  private readonly timeoutMilliseconds: number;
  private readonly maximumAttempts: number;
  private readonly now: () => number;
  private readonly sleep: (milliseconds: number) => Promise<void>;
  private blockedUntilMilliseconds = 0;

  constructor(private readonly options: FootballDataClientOptions) {
    if (options.token.trim().length === 0) throw new Error("FOOTBALL_PROVIDER_SECRET_UNAVAILABLE");
    this.fetchImplementation = options.fetch ?? fetch;
    this.baseUrl = (options.baseUrl ?? DEFAULT_BASE_URL).replace(/\/$/, "");
    this.timeoutMilliseconds = boundedInteger(options.timeoutMilliseconds, 8_000, 1_000, 15_000);
    this.maximumAttempts = boundedInteger(options.maximumAttempts, 3, 1, 3);
    this.now = options.now ?? Date.now;
    this.sleep = options.sleep ?? ((milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds)));
  }

  getMatch<T = unknown>(matchId: number): Promise<FootballDataResponse<T>> {
    return this.get(`/matches/${positiveInteger(matchId)}`);
  }

  getMatches<T = unknown>(filters: Readonly<Record<string, string>> = {}): Promise<FootballDataResponse<T>> {
    return this.get("/matches", filters);
  }

  getCompetitionMatches<T = unknown>(competitionCode: string, filters: Readonly<Record<string, string>> = {}): Promise<FootballDataResponse<T>> {
    return this.get(`/competitions/${competition(competitionCode)}/matches`, filters);
  }

  getCompetitionStandings<T = unknown>(competitionCode: string, season?: number): Promise<FootballDataResponse<T>> {
    const filters = season === undefined ? {} : { season: String(positiveInteger(season)) };
    return this.get(`/competitions/${competition(competitionCode)}/standings`, filters);
  }

  private async get<T>(path: string, query: Readonly<Record<string, string>> = {}): Promise<FootballDataResponse<T>> {
    const url = new URL(`${this.baseUrl}${path}`);
    for (const [key, value] of Object.entries(query)) url.searchParams.set(key, value);

    let lastError: FootballDataProviderError | null = null;
    for (let attempt = 1; attempt <= this.maximumAttempts; attempt += 1) {
      await this.waitForProviderWindow();
      try {
        const response = await this.fetchImplementation(url, {
          method: "GET",
          headers: { "X-Auth-Token": this.options.token, Accept: "application/json" },
          signal: AbortSignal.timeout(this.timeoutMilliseconds),
        });
        const rateLimit = parseFootballDataRateLimit(response.headers);
        this.observeRateLimit(rateLimit);

        if (response.ok) return { data: await response.json() as T, rateLimit };

        const retryable = response.status === 429 || response.status >= 500;
        lastError = new FootballDataProviderError(response.status, retryable, rateLimit.retryAfterSeconds ?? rateLimit.resetAfterSeconds);
        if (!retryable || attempt === this.maximumAttempts) throw lastError;
      } catch (error) {
        if (error instanceof FootballDataProviderError) {
          if (!error.retryable || attempt === this.maximumAttempts) throw error;
          lastError = error;
        } else {
          lastError = new FootballDataProviderError(503, true, null);
          if (attempt === this.maximumAttempts) throw lastError;
        }
      }
    }
    throw lastError ?? new FootballDataProviderError(503, true, null);
  }

  private observeRateLimit(rateLimit: FootballDataRateLimit): void {
    if (rateLimit.remainingThisMinute === 0 || rateLimit.retryAfterSeconds !== null) {
      const seconds = rateLimit.retryAfterSeconds ?? rateLimit.resetAfterSeconds ?? 60;
      this.blockedUntilMilliseconds = Math.max(this.blockedUntilMilliseconds, this.now() + seconds * 1_000);
    }
  }

  private async waitForProviderWindow(): Promise<void> {
    const delay = this.blockedUntilMilliseconds - this.now();
    if (delay > 0) await this.sleep(delay);
  }
}

export function parseFootballDataRateLimit(headers: Headers): FootballDataRateLimit {
  return {
    remainingThisMinute: nonNegativeHeader(headers, "x-requests-available-minute"),
    resetAfterSeconds: nonNegativeHeader(headers, "x-requestcounter-reset"),
    retryAfterSeconds: nonNegativeHeader(headers, "retry-after"),
  };
}

const nonNegativeHeader = (headers: Headers, name: string): number | null => {
  const value = headers.get(name);
  if (value === null || value.trim() === "") return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed >= 0 ? Math.ceil(parsed) : null;
};

const boundedInteger = (value: number | undefined, fallback: number, minimum: number, maximum: number): number =>
  Math.min(maximum, Math.max(minimum, Math.trunc(value ?? fallback)));

const positiveInteger = (value: number): number => {
  if (!Number.isSafeInteger(value) || value <= 0) throw new Error("INVALID_FOOTBALL_PROVIDER_ID");
  return value;
};

const competition = (value: string): string => {
  const normalized = value.trim().toUpperCase();
  if (!/^[A-Z0-9]{2,12}$/.test(normalized)) throw new Error("INVALID_COMPETITION_CODE");
  return normalized;
};
