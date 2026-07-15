export interface ModelInvocation {
  modelAlias: string;
  promptVersion: string;
  schemaVersion: string;
  snapshot: unknown;
  timeoutMs: number;
  correlationId: string;
}

export interface ModelGatewayResult {
  providerRequestId: string;
  rawJson: unknown;
  inputTokens?: number;
  outputTokens?: number;
}

export interface ModelGateway {
  generate(invocation: ModelInvocation): Promise<ModelGatewayResult>;
}

export interface ModelAliasResolver {
  resolve(alias: string): { provider: string; model: string };
}

export class AllowlistedModelAliasResolver implements ModelAliasResolver {
  constructor(private readonly aliases: Readonly<Record<string, { provider: string; model: string }>>) {}
  resolve(alias: string): { provider: string; model: string } {
    const resolved = this.aliases[alias];
    if (!resolved) throw new Error("MODEL_ALIAS_REJECTED");
    return resolved;
  }
}
