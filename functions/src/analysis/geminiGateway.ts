import type { ModelGateway, ModelGatewayResult, ModelInvocation } from "./modelGateway.js";

interface GeminiGatewayOptions {
  apiKey: string;
  model: string;
  responseSchema: Record<string, unknown>;
  fetch?: typeof fetch;
}

interface GeminiResponse {
  candidates?: Array<{ content?: { parts?: Array<{ text?: string }> } }>;
  usageMetadata?: { promptTokenCount?: number; candidatesTokenCount?: number };
  responseId?: string;
}

export class GeminiGateway implements ModelGateway {
  private readonly fetchImplementation: typeof fetch;

  constructor(private readonly options: GeminiGatewayOptions) {
    if (!options.apiKey.trim()) throw new Error("GEMINI_SECRET_UNAVAILABLE");
    this.fetchImplementation = options.fetch ?? fetch;
  }

  async generate(invocation: ModelInvocation): Promise<ModelGatewayResult> {
    return this.generateStructured({
      systemInstruction: systemInstruction(invocation),
      userText: `ANALYSIS_INPUT_JSON\n${JSON.stringify(invocation.snapshot)}`,
      responseSchema: this.options.responseSchema,
      timeoutMs: invocation.timeoutMs,
      correlationId: invocation.correlationId,
      maxOutputTokens: 2_500,
      temperature: 0.15,
    });
  }

  /** Generic structured call used by both the shared analysis and the personal layer. */
  async generateStructured(request: StructuredRequest): Promise<ModelGatewayResult> {
    const response = await this.fetchImplementation(
      `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(this.options.model)}:generateContent`,
      {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-goog-api-key": this.options.apiKey,
        },
        body: JSON.stringify({
          systemInstruction: { parts: [{ text: request.systemInstruction }] },
          contents: [{ role: "user", parts: [{ text: request.userText }] }],
          generationConfig: {
            responseMimeType: "application/json",
            responseJsonSchema: geminiCompatibleSchema(request.responseSchema),
            temperature: request.temperature ?? 0.2,
            maxOutputTokens: request.maxOutputTokens ?? 1_200,
            thinkingConfig: { thinkingLevel: "low" },
          },
        }),
        signal: AbortSignal.timeout(request.timeoutMs),
      },
    );

    if (!response.ok) {
      const retryable = response.status === 429 || response.status >= 500;
      throw new GeminiProviderError(response.status, retryable);
    }

    const payload = await response.json() as GeminiResponse;
    const text = payload.candidates?.[0]?.content?.parts?.map((part) => part.text ?? "").join("").trim();
    if (!text) throw new GeminiProviderError(502, true);

    let rawJson: unknown;
    try {
      rawJson = JSON.parse(text);
    } catch {
      throw new GeminiProviderError(502, true);
    }

    return {
      providerRequestId: payload.responseId ?? request.correlationId,
      rawJson,
      ...(payload.usageMetadata?.promptTokenCount !== undefined ? { inputTokens: payload.usageMetadata.promptTokenCount } : {}),
      ...(payload.usageMetadata?.candidatesTokenCount !== undefined ? { outputTokens: payload.usageMetadata.candidatesTokenCount } : {}),
    };
  }
}

export interface StructuredRequest {
  systemInstruction: string;
  userText: string;
  responseSchema: Record<string, unknown>;
  timeoutMs: number;
  correlationId: string;
  maxOutputTokens?: number;
  temperature?: number;
}

export class GeminiProviderError extends Error {
  constructor(public readonly status: number, public readonly retryable: boolean) {
    super(status === 429 ? "GEMINI_RATE_LIMITED" : "GEMINI_UNAVAILABLE");
  }
}

function systemInstruction(invocation: ModelInvocation): string {
  return [
    "You are a cautious football statistics analyst.",
    "Use only ANALYSIS_INPUT_JSON. Never use outside knowledge and never invent missing data.",
    "Return only JSON matching the supplied response schema.",
    "All probability groups must total exactly 100 using integers.",
    "Every rationale must cite one or more available sections using evidenceRefs.",
    "Every evidenceRefs item must be exactly the string \"sections.<name>\" naming an available section of ANALYSIS_INPUT_JSON, for example \"sections.recentForm\". Never a sentence, a sub-path, or any other format.",
    "Never promise an outcome, recommend betting, or use certainty language.",
    "Reflect missing information in limitations and lower confidence.",
    "Write rationale text in plain English; it is a neutral base that is localized and personalized later.",
    "Every rationale code and every limitations item must be an uppercase underscore code matching ^[A-Z0-9_]{1,64}$, never a sentence.",
    `Use schemaVersion=${invocation.schemaVersion}, promptVersion=${invocation.promptVersion}, modelVersion=${invocation.modelAlias}.`,
    "Copy all identity, timestamp, language, status and analysisId fields exactly from outputIdentity in the input.",
  ].join("\n");
}

export function geminiCompatibleSchema(schema: Record<string, unknown>): Record<string, unknown> {
  return transformSchema(schema) as Record<string, unknown>;
}

function transformSchema(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(transformSchema);
  if (!value || typeof value !== "object") return value;
  const source = value as Record<string, unknown>;
  const result: Record<string, unknown> = {};
  for (const [key, item] of Object.entries(source)) {
    if (["$schema", "$comment", "pattern", "minLength", "maxLength", "uniqueItems"].includes(key)) continue;
    if (key === "const") {
      result.enum = [item];
      continue;
    }
    result[key] = transformSchema(item);
  }
  return result;
}
