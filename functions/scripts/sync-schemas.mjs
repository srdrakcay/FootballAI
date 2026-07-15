import { cp, mkdir } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const sourceDirectory = resolve(scriptDirectory, "../../schemas");
const destinationDirectory = resolve(scriptDirectory, "../generated-schemas");

await mkdir(destinationDirectory, { recursive: true });
for (const name of ["analysis-input-snapshot.schema.json", "analysis-result.schema.json"]) {
  await cp(resolve(sourceDirectory, name), resolve(destinationDirectory, name));
}
