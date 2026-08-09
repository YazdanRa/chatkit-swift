#!/usr/bin/env node

const childProcess = require("child_process");
const fs = require("fs");
const path = require("path");

const CREATE_WIDGET_URL = "https://widgets.chatkit.studio/create-widget";
const CONVERT_WIDGET_URL = "https://widgets.chatkit.studio/convert-widget-to-file";
const NUNJUCKS_VERSION = "3.2.4";
const UNDEFINED_SENTINEL = "__chatkit_widget_undefined__";
const DEFAULT_PROMPTS = "WidgetParity/prompts/generated-widget-prompts.json";
const DEFAULT_OUTPUT = "WidgetParity/fixtures/generated-widgets.json";
const DEFAULT_PARITY_OUTPUT = ".widget-parity/generated";
const DEFAULT_TOOL_ROOT = ".widget-parity/widget-fuzz-node";
const DEFAULT_USER_ID = "153bb90a-c86a-4f76-9f78-b47aea680d85";
const DEFAULT_COUNT = 100;
const MAX_COUNT = 300;
const DEFAULT_CONCURRENCY = 4;
const DEFAULT_RETRIES = 2;
const DEFAULT_THRESHOLD = 0.28;
const DEFAULT_VIEWPORTS = [
  { width: 360, height: 640 },
  { width: 480, height: 640 },
  { width: 720, height: 720 },
  { width: 800, height: 640 },
  { width: 980, height: 720 },
];

main().catch((error) => {
  console.error(error instanceof Error ? error.stack || error.message : String(error));
  process.exitCode = 1;
});

async function main() {
  const options = parseArguments(process.argv.slice(2));
  if (options.help) {
    printHelp();
    return;
  }

  const repoRoot = process.cwd();
  const corpus = readJSON(path.resolve(repoRoot, options.promptFile));
  const prompts = selectPrompts(corpus.prompts || [], options);
  const outputPath = path.resolve(repoRoot, options.output);
  const existingManifest = options.resume && fs.existsSync(outputPath)
    ? readJSON(outputPath)
    : { version: 1, source: CREATE_WIDGET_URL, generatedAt: null, fixtures: [], failures: [] };
  const completedPromptIds = new Set((existingManifest.fixtures || []).map((fixture) => fixture.metadata?.promptId).filter(Boolean));
  const pendingPrompts = prompts.filter((prompt) => !completedPromptIds.has(prompt.id));

  if (options.dryRun) {
    writeManifest(outputPath, buildManifest(existingManifest.fixtures || [], [], options, prompts.length));
    console.log(`Prepared ${prompts.length} generated widget prompts at ${outputPath}`);
    return;
  }

  const renderer = loadTemplateRenderer(repoRoot, options);
  console.log(`Generating ${pendingPrompts.length}/${prompts.length} widgets from ${CREATE_WIDGET_URL} with concurrency ${options.concurrency}...`);
  const results = await mapLimit(pendingPrompts, options.concurrency, async (prompt, index) => {
    const fixtureIndex = prompts.findIndex((candidate) => candidate.id === prompt.id);
    return generateFixture(prompt, fixtureIndex >= 0 ? fixtureIndex : index, options, renderer);
  });

  const fixtures = [...(existingManifest.fixtures || [])];
  const retryPromptIds = new Set(pendingPrompts.map((prompt) => prompt.id));
  const failures = (existingManifest.failures || []).filter((failure) => !retryPromptIds.has(failure.promptId));
  for (const result of results) {
    if (result.fixture) {
      fixtures.push(result.fixture);
    } else {
      failures.push(result.failure);
    }
  }

  fixtures.sort((left, right) => (left.metadata?.index ?? 0) - (right.metadata?.index ?? 0));
  writeManifest(outputPath, buildManifest(fixtures, failures, options, prompts.length));
  console.log(`Generated ${fixtures.length}/${prompts.length} fixtures at ${outputPath}`);
  if (failures.length > 0) {
    console.log(`Generation failures: ${failures.length}`);
  }

  if (options.runParity) {
    const parityArgs = [
      "scripts/widget-parity.js",
      "--fixtures",
      options.output,
      "--output",
      options.parityOutput,
    ];
    if (options.visualReview) parityArgs.push("--visual-review");
    if (options.allowFailures) parityArgs.push("--allow-failures");
    runCommand(process.execPath, parityArgs);
  }

  if (failures.length > 0 && !options.allowFailures) {
    process.exitCode = 1;
  }
}

function parseArguments(args) {
  const options = {
    promptFile: DEFAULT_PROMPTS,
    output: DEFAULT_OUTPUT,
    parityOutput: DEFAULT_PARITY_OUTPUT,
    toolRoot: DEFAULT_TOOL_ROOT,
    userId: DEFAULT_USER_ID,
    count: DEFAULT_COUNT,
    concurrency: DEFAULT_CONCURRENCY,
    threshold: DEFAULT_THRESHOLD,
    retries: DEFAULT_RETRIES,
    resume: false,
    noInstall: false,
    allowFailures: false,
    runParity: false,
    visualReview: false,
    dryRun: false,
    help: false,
  };

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    switch (arg) {
      case "--prompt-file":
        options.promptFile = readValue(args, ++index, arg);
        break;
      case "--output":
        options.output = readValue(args, ++index, arg);
        break;
      case "--parity-output":
        options.parityOutput = readValue(args, ++index, arg);
        break;
      case "--tool-root":
        options.toolRoot = readValue(args, ++index, arg);
        break;
      case "--user-id":
        options.userId = readValue(args, ++index, arg);
        break;
      case "--count":
        options.count = parseInteger(readValue(args, ++index, arg), arg);
        break;
      case "--concurrency":
        options.concurrency = parseInteger(readValue(args, ++index, arg), arg);
        break;
      case "--threshold":
        options.threshold = Number(readValue(args, ++index, arg));
        break;
      case "--retries":
        options.retries = parseInteger(readValue(args, ++index, arg), arg);
        break;
      case "--resume":
        options.resume = true;
        break;
      case "--no-install":
        options.noInstall = true;
        break;
      case "--allow-failures":
        options.allowFailures = true;
        break;
      case "--run-parity":
        options.runParity = true;
        break;
      case "--visual-review":
        options.visualReview = true;
        break;
      case "--dry-run":
        options.dryRun = true;
        break;
      case "--help":
      case "-h":
        options.help = true;
        break;
      default:
        throw new Error(`Unknown argument: ${arg}`);
    }
  }

  if (!Number.isFinite(options.threshold) || options.threshold < 0 || options.threshold >= 1) {
    throw new Error("--threshold must be a number >= 0 and < 1.");
  }
  if (options.count < 1 || options.count > MAX_COUNT) {
    throw new Error(`--count must be between 1 and ${MAX_COUNT}.`);
  }
  if (options.concurrency < 1 || options.concurrency > 12) {
    throw new Error("--concurrency must be between 1 and 12.");
  }
  if (options.retries < 0 || options.retries > 5) {
    throw new Error("--retries must be between 0 and 5.");
  }
  return options;
}

function printHelp() {
  console.log(`
Usage: node scripts/widget-fuzz.js [options]

Options:
  --prompt-file <path>   Prompt corpus. Default: ${DEFAULT_PROMPTS}
  --output <path>        Generated fixture manifest. Default: ${DEFAULT_OUTPUT}
  --parity-output <path> Output directory when --run-parity is used. Default: ${DEFAULT_PARITY_OUTPUT}
  --tool-root <path>     Local tool dependency root. Default: ${DEFAULT_TOOL_ROOT}
  --user-id <id>         Widget Studio user id. Default: ${DEFAULT_USER_ID}
  --count <n>            Number of widgets to generate. Default: ${DEFAULT_COUNT}; max: ${MAX_COUNT}
  --concurrency <n>      Concurrent Studio generations. Default: ${DEFAULT_CONCURRENCY}
  --retries <n>          Retries per Studio request. Default: ${DEFAULT_RETRIES}
  --threshold <n>        Pixel threshold assigned to generated fixtures. Default: ${DEFAULT_THRESHOLD}
  --resume               Skip prompts already present in the output manifest.
  --no-install           Do not bootstrap Nunjucks into the local tool root.
  --allow-failures       Keep partial output and return success when generation/parity has failures.
  --run-parity           Run scripts/widget-parity.js against the generated manifest.
  --visual-review        Pass --visual-review through when --run-parity is set.
  --dry-run              Write manifest metadata without calling Studio.
`);
}

function readValue(args, index, option) {
  if (index >= args.length) {
    throw new Error(`Missing value for ${option}`);
  }
  return args[index];
}

function parseInteger(value, option) {
  const parsed = Number(value);
  if (!Number.isInteger(parsed)) {
    throw new Error(`${option} must be an integer.`);
  }
  return parsed;
}

function readJSON(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function selectPrompts(prompts, options) {
  if (!Array.isArray(prompts) || prompts.length === 0) {
    throw new Error("Prompt corpus must include a non-empty prompts array.");
  }
  return prompts.slice(0, options.count);
}

async function generateFixture(prompt, index, options, renderer) {
  let generated = null;
  let converted = null;
  let renderedJSON = null;
  try {
    generated = await postJSON(CREATE_WIDGET_URL, {
      userId: options.userId,
      prompt: prompt.prompt,
      attachments: prompt.attachments || [],
    }, options);
    if (!generated.view) {
      throw new Error(`create-widget response did not include a view for ${prompt.id}`);
    }

    converted = await postJSON(CONVERT_WIDGET_URL, { widgetJsx: generated.view }, options);
    if (!converted.template) {
      throw new Error(`convert-widget-to-file response did not include a template for ${prompt.id}`);
    }

    renderedJSON = renderTemplate(converted.template, generated.state || {}, renderer);
    const widget = normalizeWidget(JSON.parse(renderedJSON));
    const fixture = {
      id: `gen-${String(index + 1).padStart(3, "0")}-${prompt.id}`,
      name: generated.name || titleFromId(prompt.id),
      theme: prompt.theme || (index % 5 === 4 ? "dark" : "light"),
      viewport: prompt.viewport || DEFAULT_VIEWPORTS[index % DEFAULT_VIEWPORTS.length],
      threshold: prompt.threshold ?? options.threshold,
      widget,
      metadata: {
        source: CREATE_WIDGET_URL,
        promptId: prompt.id,
        prompt: prompt.prompt,
        index,
        generatedName: generated.name || null,
        generatedAt: new Date().toISOString(),
        view: generated.view,
        schema: generated.schema || null,
        state: generated.state || {},
      },
    };
    console.log(`Generated ${fixture.id}`);
    return { fixture };
  } catch (error) {
    const failure = {
      promptId: prompt.id,
      prompt: prompt.prompt,
      index,
      error: error instanceof Error ? error.message : String(error),
      generatedName: generated?.name || null,
      view: generated?.view || null,
      state: generated?.state || null,
      template: converted?.template || null,
      renderedJSON,
    };
    console.log(`Failed ${prompt.id}: ${failure.error}`);
    return { failure };
  }
}

async function postJSON(url, payload, options) {
  let lastError = null;
  for (let attempt = 0; attempt <= options.retries; attempt += 1) {
    try {
      const response = await fetch(url, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Origin": "https://widgets.chatkit.studio",
          "Referer": "https://widgets.chatkit.studio/editor/generated-fuzz",
          "Accept": "application/json",
        },
        body: JSON.stringify(payload),
      });
      const text = await response.text();
      if (!response.ok) {
        throw new Error(`${url} returned ${response.status}: ${text.slice(0, 500)}`);
      }
      try {
        return JSON.parse(text);
      } catch {
        throw new Error(`${url} returned non-JSON response: ${text.slice(0, 500)}`);
      }
    } catch (error) {
      lastError = error;
      if (attempt < options.retries) {
        await sleep(300 * (attempt + 1));
      }
    }
  }
  throw lastError;
}

function renderTemplate(template, state, renderer) {
  const rendered = renderer.render(template, state);
  if (rendered.includes("{{") || rendered.includes("{%")) {
    throw new Error("Widget template contains unsupported state interpolation syntax.");
  }
  return rendered;
}

function normalizeWidget(value) {
  if (Array.isArray(value)) {
    return value.map(normalizeWidget);
  }
  if (!value || typeof value !== "object") {
    return value;
  }

  const normalized = {};
  for (const [key, child] of Object.entries(value)) {
    if (key === "key" || child === UNDEFINED_SENTINEL) {
      continue;
    }
    normalized[key] = normalizeWidget(child);
  }
  return normalized;
}

function loadTemplateRenderer(repoRoot, options) {
  let nunjucks = null;
  try {
    nunjucks = require("nunjucks");
  } catch {
    if (options.noInstall) {
      throw new Error("Nunjucks is not installed. Remove --no-install or install nunjucks locally.");
    }
  }

  if (!nunjucks) {
    const nodeRoot = path.resolve(repoRoot, options.toolRoot);
    ensureDirectory(nodeRoot);
    const packageJSONPath = path.join(nodeRoot, "package.json");
    if (!fs.existsSync(packageJSONPath)) {
      fs.writeFileSync(packageJSONPath, JSON.stringify({
        private: true,
        dependencies: {
          nunjucks: NUNJUCKS_VERSION,
        },
      }, null, 2));
    }

    const packagePath = path.join(nodeRoot, "node_modules", "nunjucks");
    if (!fs.existsSync(packagePath)) {
      runCommand("npm", ["install", "--prefix", nodeRoot, `nunjucks@${NUNJUCKS_VERSION}`]);
    }
    nunjucks = require(packagePath);
  }

  return createTemplateRenderer(nunjucks);
}

function createTemplateRenderer(nunjucks) {
  const environment = new nunjucks.Environment(null, {
    autoescape: false,
    throwOnUndefined: true,
  });
  environment.addFilter("tojson", (value) => JSON.stringify(value === undefined ? UNDEFINED_SENTINEL : value));
  environment.addFilter("trimLeadingComma", (value) => {
    if (typeof value !== "string") {
      return value;
    }
    return value.startsWith(",") ? value.slice(1) : value;
  });

  return {
    render(template, state) {
      return environment.renderString(normalizeStudioTemplate(template), state);
    },
  };
}

function normalizeStudioTemplate(template) {
  return template.replace(
    /\{\{-\s*\(_c\[1:\]\s+if\s+_c\s+and\s+_c\[0\]\s*==\s*','\s+else\s+_c\)\s*-\}\}/g,
    "{{ _c | trimLeadingComma | safe }}",
  );
}

async function mapLimit(items, concurrency, worker) {
  const results = new Array(items.length);
  let nextIndex = 0;
  async function runNext() {
    while (nextIndex < items.length) {
      const index = nextIndex;
      nextIndex += 1;
      results[index] = await worker(items[index], index);
    }
  }
  await Promise.all(Array.from({ length: Math.min(concurrency, items.length) }, runNext));
  return results;
}

function buildManifest(fixtures, failures, options, requestedCount) {
  return {
    version: 1,
    source: CREATE_WIDGET_URL,
    requestedCount,
    generatedAt: new Date().toISOString(),
    fixtures,
    failures,
  };
}

function writeManifest(outputPath, manifest) {
  ensureDirectory(path.dirname(outputPath));
  fs.writeFileSync(outputPath, `${JSON.stringify(manifest, null, 2)}\n`);
}

function ensureDirectory(directory) {
  fs.mkdirSync(directory, { recursive: true });
}

function runCommand(command, args) {
  const result = childProcess.spawnSync(command, args, {
    cwd: process.cwd(),
    stdio: "inherit",
  });
  if (result.status !== 0) {
    throw new Error(`${command} ${args.join(" ")} failed with exit code ${result.status}`);
  }
}

function sleep(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

function titleFromId(id) {
  return id
    .split("-")
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(" ");
}
