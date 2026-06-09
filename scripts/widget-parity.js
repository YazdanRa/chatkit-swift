#!/usr/bin/env node

const childProcess = require("child_process");
const fs = require("fs");
const http = require("http");
const path = require("path");
const zlib = require("zlib");

const DEFAULT_CHATKIT_JS = "/Users/ericlewis/Developer/chatkit-js";
const DEFAULT_FIXTURES = "WidgetParity/fixtures/widgets.json";
const DEFAULT_OUTPUT = ".widget-parity";
const DEFAULT_VISUAL_MODEL = process.env.OPENAI_VISION_MODEL || "gpt-5.4-mini-2026-03-17";
const PLAYWRIGHT_VERSION = "1.60.0";
const RESPONSES_API_URL = "https://api.openai.com/v1/responses";
const VISUAL_REVIEW_RESPONSE_FORMAT = {
  type: "json_schema",
  name: "chatkit_widget_visual_review",
  strict: true,
  schema: {
    type: "object",
    additionalProperties: false,
    properties: {
      verdict: { type: "string", enum: ["pass", "fail", "review"] },
      confidence: { type: "string", enum: ["low", "medium", "high"] },
      summary: { type: "string" },
      issues: {
        type: "array",
        maxItems: 8,
        items: {
          type: "object",
          additionalProperties: false,
          properties: {
            severity: { type: "string", enum: ["minor", "moderate", "major"] },
            category: {
              type: "string",
              enum: ["content", "layout", "theme", "typography", "controls", "actions", "clipping", "spacing", "crop", "other"],
            },
            description: { type: "string" },
            swift_only: { type: "boolean" },
          },
          required: ["severity", "category", "description", "swift_only"],
        },
      },
      ignored_differences: {
        type: "array",
        maxItems: 8,
        items: { type: "string" },
      },
    },
    required: ["verdict", "confidence", "summary", "issues", "ignored_differences"],
  },
};

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
  if (options.visualReview && !process.env.OPENAI_API_KEY) {
    throw new Error("--visual-review requires OPENAI_API_KEY in the environment.");
  }

  const repoRoot = process.cwd();
  const fixturesPath = path.resolve(repoRoot, options.fixtures);
  const outputRoot = path.resolve(repoRoot, options.output);
  const swiftOutput = path.join(outputRoot, "swift");
  const swiftCropOutput = path.join(outputRoot, "swift-crop");
  const jsOutput = path.join(outputRoot, "js");
  const diffOutput = path.join(outputRoot, "diff");

  const manifest = JSON.parse(fs.readFileSync(fixturesPath, "utf8"));
  ensureDirectory(outputRoot);
  ensureDirectory(swiftOutput);
  ensureDirectory(swiftCropOutput);
  ensureDirectory(jsOutput);
  ensureDirectory(diffOutput);

  if (!options.skipSwift) {
    runCommand("xcrun", [
      "--toolchain",
      "XcodeDefault",
      "swift",
      "run",
      "ChatKitWidgetSnapshot",
      "--fixtures",
      fixturesPath,
      "--output",
      swiftOutput,
    ]);
  }

  const playwright = await loadPlaywright(outputRoot, options);
  const chatkitRoot = path.resolve(options.chatkitJs);
  const server = await startServer({
    manifest,
    chatkitRoot,
    outputRoot,
    assetOrigin: options.assetOrigin,
  });

  try {
    await captureReferenceScreenshots(playwright, server, manifest, jsOutput);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }

  const report = compareScreenshots(manifest, {
    swiftOutput,
    swiftCropOutput,
    jsOutput,
    diffOutput,
  });
  if (options.visualReview) {
    report.visualReview = {
      model: options.visualModel,
      detail: options.visualDetail,
      reviewedAt: new Date().toISOString(),
    };
    report.visualReviews = await runVisualReviews(report, {
      swiftCropOutput,
      jsOutput,
      diffOutput,
    }, options);
  }
  writeReport(report, outputRoot);

  const failed = report.results.filter((result) => !result.passed);
  const counts = visualReviewCounts(report.visualReviews || []);
  const pixelFailuresAreBlocking = !options.visualReview && failed.length > 0;
  console.log(`Widget parity: ${report.results.length - failed.length}/${report.results.length} fixtures within threshold.`);
  if (report.visualReviews) {
    console.log(`Visual review: ${counts.pass} pass, ${counts.review} review, ${counts.fail} fail by ${options.visualModel}.`);
  }
  console.log(`Report: ${path.join(outputRoot, "report.md")}`);
  if ((pixelFailuresAreBlocking || counts.fail > 0) && !options.allowFailures) {
    process.exitCode = 1;
  }
}

function visualReviewCounts(reviews) {
  return reviews.reduce((counts, review) => {
    if (review.verdict === "pass") {
      counts.pass += 1;
    } else if (review.verdict === "review") {
      counts.review += 1;
    } else if (review.verdict === "fail") {
      counts.fail += 1;
    }
    return counts;
  }, { pass: 0, review: 0, fail: 0 });
}

function parseArguments(args) {
  const options = {
    fixtures: DEFAULT_FIXTURES,
    output: DEFAULT_OUTPUT,
    chatkitJs: DEFAULT_CHATKIT_JS,
    assetOrigin: "https://cdn.platform.openai.com",
    skipSwift: false,
    noInstall: false,
    allowFailures: false,
    visualReview: false,
    visualModel: DEFAULT_VISUAL_MODEL,
    visualDetail: "auto",
    help: false,
  };

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    switch (arg) {
      case "--fixtures":
        options.fixtures = readValue(args, ++index, arg);
        break;
      case "--output":
        options.output = readValue(args, ++index, arg);
        break;
      case "--chatkit-js":
        options.chatkitJs = readValue(args, ++index, arg);
        break;
      case "--asset-origin":
        options.assetOrigin = readValue(args, ++index, arg).replace(/\/$/, "");
        break;
      case "--skip-swift":
        options.skipSwift = true;
        break;
      case "--no-install":
        options.noInstall = true;
        break;
      case "--allow-failures":
        options.allowFailures = true;
        break;
      case "--visual-review":
        options.visualReview = true;
        break;
      case "--visual-model":
        options.visualModel = readValue(args, ++index, arg);
        break;
      case "--visual-detail":
        options.visualDetail = readValue(args, ++index, arg);
        break;
      case "--help":
      case "-h":
        options.help = true;
        break;
      default:
        throw new Error(`Unknown argument: ${arg}`);
    }
  }

  if (!["low", "auto", "high"].includes(options.visualDetail)) {
    throw new Error("--visual-detail must be one of: low, auto, high.");
  }

  return options;
}

function printHelp() {
  console.log(`
Usage: node scripts/widget-parity.js [options]

Options:
  --fixtures <path>      Fixture manifest. Default: ${DEFAULT_FIXTURES}
  --output <path>        Output directory. Default: ${DEFAULT_OUTPUT}
  --chatkit-js <path>    Local chatkit-js checkout. Default: ${DEFAULT_CHATKIT_JS}
  --asset-origin <url>   Fallback origin for missing /assets/ck1 chunks.
  --skip-swift           Reuse existing Swift screenshots.
  --no-install           Do not bootstrap Playwright into the output directory.
  --allow-failures       Generate the report without returning a failing exit code.
  --visual-review        Ask a visual model to review Swift, JS, and diff images.
  --visual-model <name>  OpenAI model for visual review. Default: ${DEFAULT_VISUAL_MODEL}
  --visual-detail <mode> Image detail for visual review: low, auto, high. Default: auto
`);
}

function readValue(args, index, option) {
  if (index >= args.length) {
    throw new Error(`Missing value for ${option}`);
  }
  return args[index];
}

function ensureDirectory(directory) {
  fs.mkdirSync(directory, { recursive: true });
}

function runCommand(command, args, options = {}) {
  const result = childProcess.spawnSync(command, args, {
    cwd: process.cwd(),
    stdio: "inherit",
    ...options,
  });
  if (result.status !== 0) {
    throw new Error(`${command} ${args.join(" ")} failed with exit code ${result.status}`);
  }
}

async function loadPlaywright(outputRoot, options) {
  try {
    const module = require("playwright");
    module.__packageRoot = path.dirname(require.resolve("playwright/package.json"));
    return module;
  } catch {
    if (options.noInstall) {
      throw new Error("Playwright is not installed. Remove --no-install or install playwright locally.");
    }
  }

  const nodeRoot = path.join(outputRoot, "node");
  ensureDirectory(nodeRoot);
  const packageJSONPath = path.join(nodeRoot, "package.json");
  if (!fs.existsSync(packageJSONPath)) {
    fs.writeFileSync(packageJSONPath, JSON.stringify({
      private: true,
      dependencies: {
        playwright: PLAYWRIGHT_VERSION,
      },
    }, null, 2));
  }

  const packagePath = path.join(nodeRoot, "node_modules", "playwright");
  if (!fs.existsSync(packagePath)) {
    runCommand("npm", ["install", "--prefix", nodeRoot, `playwright@${PLAYWRIGHT_VERSION}`]);
  }

  const module = require(packagePath);
  module.__packageRoot = packagePath;
  return module;
}

async function startServer({ manifest, chatkitRoot, outputRoot, assetOrigin }) {
  const runtimeRoot = path.join(chatkitRoot, "packages", "chatkit", "runtime");
  const referencesRoot = path.join(chatkitRoot, "remote_references_to");
  const assetCache = path.join(outputRoot, "asset-cache");
  ensureDirectory(assetCache);

  const server = http.createServer((request, response) => {
    handleRequest(request, response).catch((error) => {
      response.statusCode = 500;
      response.end(String(error instanceof Error ? error.stack || error.message : error));
    });
  });

  async function handleRequest(request, response) {
    const url = new URL(request.url || "/", "http://127.0.0.1");
    if (url.pathname === "/") {
      response.writeHead(302, { Location: `/fixture/${manifest.fixtures[0].id}` });
      response.end();
      return;
    }

    if (url.pathname.startsWith("/fixture/")) {
      const id = decodeURIComponent(url.pathname.slice("/fixture/".length));
      const fixture = manifest.fixtures.find((entry) => entry.id === id);
      if (!fixture) {
        sendText(response, 404, "Missing fixture");
        return;
      }
      sendText(response, 200, renderFixturePage(fixture), "text/html; charset=utf-8");
      return;
    }

    if (url.pathname === "/chatkit/chatkit.js") {
      sendFile(response, path.join(runtimeRoot, "chatkit.js"), "application/javascript");
      return;
    }

    if (url.pathname === "/chatkit/index-Z3oXPNtZsl.html") {
      sendFile(response, path.join(runtimeRoot, "index-Z3oXPNtZsl.html"), "text/html; charset=utf-8");
      return;
    }

    if (url.pathname === "/assets/ck1/index-DxZJUpHO.js") {
      sendFile(response, path.join(referencesRoot, "index-DxZJUpHO.js"), "application/javascript");
      return;
    }

    if (url.pathname === "/assets/ck1/index-D9b2ZX6j.css") {
      sendFile(response, path.join(referencesRoot, "index-D9b2ZX6j.css"), "text/css");
      return;
    }

    if (url.pathname.startsWith("/assets/ck1/")) {
      const cachedPath = path.join(assetCache, path.basename(url.pathname));
      if (fs.existsSync(cachedPath)) {
        sendFile(response, cachedPath, contentTypeForPath(cachedPath));
        return;
      }

      const remote = new URL(url.pathname, assetOrigin);
      const fetched = await fetch(remote);
      if (!fetched.ok) {
        sendText(response, 404, `Missing asset: ${url.pathname}`);
        return;
      }
      const buffer = Buffer.from(await fetched.arrayBuffer());
      fs.writeFileSync(cachedPath, buffer);
      response.writeHead(200, { "Content-Type": fetched.headers.get("content-type") || contentTypeForPath(cachedPath) });
      response.end(buffer);
      return;
    }

    sendText(response, 404, "Not found");
  }

  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  const { port } = server.address();
  server.baseURL = `http://127.0.0.1:${port}`;
  return server;
}

function sendFile(response, filePath, contentType) {
  if (!fs.existsSync(filePath)) {
    sendText(response, 404, `Missing file: ${filePath}`);
    return;
  }
  response.writeHead(200, { "Content-Type": contentType });
  fs.createReadStream(filePath).pipe(response);
}

function sendText(response, status, text, contentType = "text/plain; charset=utf-8") {
  response.writeHead(status, { "Content-Type": contentType });
  response.end(text);
}

function contentTypeForPath(filePath) {
  if (filePath.endsWith(".js")) return "application/javascript";
  if (filePath.endsWith(".css")) return "text/css";
  if (filePath.endsWith(".svg")) return "image/svg+xml";
  if (filePath.endsWith(".ico")) return "image/x-icon";
  if (filePath.endsWith(".png")) return "image/png";
  return "application/octet-stream";
}

function renderFixturePage(fixture) {
  const fixtureJSON = JSON.stringify(fixture).replace(/</g, "\\u003c");
  const background = fixture.theme === "dark" ? "#080A0F" : "#FFFFFF";
  return `<!doctype html>
<html>
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <script src="/chatkit/chatkit.js"></script>
    <style>
      html, body {
        margin: 0;
        width: ${fixture.viewport.width}px;
        height: ${fixture.viewport.height}px;
        overflow: hidden;
        background: ${background};
      }
      openai-chatkit {
        display: block;
        width: ${fixture.viewport.width}px;
        height: ${fixture.viewport.height}px;
        background: ${background};
      }
    </style>
  </head>
  <body>
    <openai-chatkit id="chatkit"></openai-chatkit>
    <script>
      const fixture = ${fixtureJSON};
      const threadId = "thread_" + fixture.id;
      const item = {
        type: "widget",
        id: "widget_" + fixture.id,
        thread_id: threadId,
        created_at: "2026-06-08T00:00:01.000Z",
        widget: fixture.widget
      };
      const thread = {
        id: threadId,
        title: fixture.name,
        created_at: "2026-06-08T00:00:00.000Z",
        status: { type: "active" },
        metadata: {},
        items: { data: [item], has_more: false, after: null }
      };

      window.__chatkitRequests = [];
      window.__chatkitErrors = [];
      window.__chatkitReady = false;

      function jsonResponse(payload) {
        return new Response(JSON.stringify(payload), {
          status: 200,
          headers: { "Content-Type": "application/json" }
        });
      }

      async function fixtureFetch(url, params = {}) {
        const rawBody = params.body ? String(params.body) : "{}";
        const body = JSON.parse(rawBody || "{}");
        const op = body.type || body.op;
        window.__chatkitRequests.push({ url, op, body });
        if (op === "threads.get_by_id") return jsonResponse(thread);
        if (op === "items.list") return jsonResponse(thread.items);
        if (op === "threads.list") return jsonResponse({ data: [thread], has_more: false, after: null });
        if (op === "items.feedback") return jsonResponse({ ok: true });
        return jsonResponse({});
      }

      const chatkit = document.getElementById("chatkit");
      chatkit.addEventListener("chatkit.ready", () => {
        window.__chatkitReady = true;
      });
      chatkit.addEventListener("chatkit.error", (event) => {
        window.__chatkitErrors.push(event.detail?.error?.message || String(event.detail?.error || event));
      });
      chatkit.setOptions({
        api: {
          url: "/api/chatkit",
          domainKey: "local-parity",
          fetch: fixtureFetch
        },
        initialThread: threadId,
        frameTitle: fixture.name,
        locale: "en",
        theme: { colorScheme: fixture.theme || "light" },
        header: { enabled: false },
        history: { enabled: false },
        threadItemActions: { feedback: false, retry: false },
        composer: { placeholder: " " },
        widgets: {
          onAction: async () => {}
        }
      });
    </script>
  </body>
</html>`;
}

async function captureReferenceScreenshots(playwright, server, manifest, outputDirectory) {
  const browser = await launchChromium(playwright);
  try {
    const context = await browser.newContext({ deviceScaleFactor: 2 });
    const page = await context.newPage();
    page.on("console", (message) => {
      if (message.type() === "error" || message.type() === "warning") {
        console.log(`[browser:${message.type()}] ${message.text()}`);
      }
    });
    page.on("pageerror", (error) => {
      console.log(`[browser:error] ${error.message}`);
    });
    page.on("requestfailed", (request) => {
      console.log(`[browser:requestfailed] ${request.url()} ${request.failure()?.errorText || ""}`);
    });

    for (const fixture of manifest.fixtures) {
      await page.setViewportSize({
        width: fixture.viewport.width,
        height: fixture.viewport.height,
      });
      await page.goto(`${server.baseURL}/fixture/${encodeURIComponent(fixture.id)}`, {
        waitUntil: "domcontentloaded",
      });

      const frame = await waitForChatKitFrame(page);
      await frame.waitForLoadState("domcontentloaded", { timeout: 30000 }).catch(() => {});
      const needle = firstWidgetNeedle(fixture.widget);
      await frame.waitForFunction((value) => document.body.innerText.includes(value), needle, { timeout: 30000 }).catch(async (error) => {
        const state = await page.evaluate(() => ({
          ready: window.__chatkitReady,
          errors: window.__chatkitErrors,
          requests: window.__chatkitRequests,
          hostDefined: Boolean(customElements.get("openai-chatkit")),
        }));
        throw new Error(`${error.message}\nHost state: ${JSON.stringify(state, null, 2)}`);
      });
      await frame.waitForTimeout(400);

      const box = await frame.evaluate((value) => {
        function findTextElement(root, text) {
          const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
          let node = walker.nextNode();
          while (node) {
            if ((node.textContent || "").includes(text)) {
              return node.parentElement;
            }
            node = walker.nextNode();
          }
          return null;
        }

        const start = findTextElement(document.body, value);
        if (!start) return null;

        const candidates = [];
        for (let element = start; element && element !== document.body; element = element.parentElement) {
          const rect = element.getBoundingClientRect();
          const text = element.innerText || element.textContent || "";
          const fullFrame = rect.width >= window.innerWidth - 4 && rect.height >= window.innerHeight - 4;
          if (
            text.includes(value) &&
            rect.width >= 80 &&
            rect.height >= 20 &&
            rect.height <= window.innerHeight * 0.85 &&
            !fullFrame
          ) {
            candidates.push({
              x: rect.left,
              y: rect.top,
              width: rect.width,
              height: rect.height,
              area: rect.width * rect.height,
            });
          }
        }

        const best = candidates.sort((left, right) => right.area - left.area)[0];
        if (!best) {
          const rect = start.getBoundingClientRect();
          return { x: rect.left, y: rect.top, width: rect.width, height: rect.height };
        }
        const pad = 4;
        return {
          x: Math.max(0, Math.floor(best.x - pad)),
          y: Math.max(0, Math.floor(best.y - pad)),
          width: Math.ceil(best.width + pad * 2),
          height: Math.ceil(best.height + pad * 2),
        };
      }, needle);
      const iframe = await page.locator("openai-chatkit").evaluateHandle((host) => host.shadowRoot.querySelector("iframe"));
      const iframeBox = await iframe.asElement().boundingBox();
      if (!iframeBox || !box) {
        throw new Error(`Unable to locate JS widget box for fixture ${fixture.id}`);
      }

      const screenshotPath = path.join(outputDirectory, `${fixture.id}.png`);
      await page.screenshot({
        path: screenshotPath,
        clip: {
          x: Math.max(0, iframeBox.x + box.x),
          y: Math.max(0, iframeBox.y + box.y),
          width: Math.max(1, Math.min(box.width, fixture.viewport.width - box.x)),
          height: Math.max(1, Math.min(box.height, fixture.viewport.height - box.y)),
        },
      });
      cropPngFileToContent(screenshotPath);
      console.log(`Captured ${path.join(outputDirectory, `${fixture.id}.png`)}`);
    }

    await context.close();
  } finally {
    await browser.close();
  }
}

function cropPngFileToContent(filePath) {
  const image = decodePng(fs.readFileSync(filePath));
  const bounds = firstContentClusterBounds(image, image.data.slice(0, 4), 10, 96);
  fs.writeFileSync(filePath, encodePng(cropImage(image, bounds)));
}

async function launchChromium(playwright) {
  try {
    return await playwright.chromium.launch({ headless: true });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    if (!message.includes("Executable doesn't exist") && !message.includes("browserType.launch")) {
      throw error;
    }
    const packageRoot = playwright.__packageRoot || path.dirname(require.resolve("playwright/package.json"));
    const playwrightBin = path.join(packageRoot, "cli.js");
    runCommand(process.execPath, [playwrightBin, "install", "chromium"]);
    return playwright.chromium.launch({ headless: true });
  }
}

async function waitForChatKitFrame(page) {
  const deadline = Date.now() + 30000;
  while (Date.now() < deadline) {
    for (const frame of page.frames()) {
      if (frame.name() === "chatkit" && frame.url().includes("index-Z3oXPNtZsl.html")) {
        return frame;
      }
    }
    await page.waitForTimeout(100);
  }
  throw new Error("Timed out waiting for ChatKit iframe.");
}

function firstWidgetNeedle(node) {
  if (!node || typeof node !== "object") return "";
  if (["Title", "Text", "Caption", "Label"].includes(node.type) && typeof node.value === "string") {
    return node.value;
  }
  if (node.type === "Badge" && typeof node.label === "string") {
    return node.label;
  }
  for (const child of widgetChildren(node)) {
    const value = firstWidgetNeedle(child);
    if (value) return value;
  }
  return node.type;
}

function widgetChildren(node) {
  if (!node || typeof node !== "object") return [];
  if (Array.isArray(node.children)) return node.children;
  if (node.children && typeof node.children === "object") return [node.children];
  return [];
}

function compareScreenshots(manifest, paths) {
  const results = [];
  for (const fixture of manifest.fixtures) {
    const nativePath = path.join(paths.swiftOutput, `${fixture.id}.png`);
    const jsPath = path.join(paths.jsOutput, `${fixture.id}.png`);
    const native = decodePng(fs.readFileSync(nativePath));
    const js = decodePng(fs.readFileSync(jsPath));

    const nativeBounds = contentBounds(native, native.data.slice(0, 4), 10);
    const croppedNative = cropImage(native, nativeBounds);
    const croppedNativePath = path.join(paths.swiftCropOutput, `${fixture.id}.png`);
    fs.writeFileSync(croppedNativePath, encodePng(croppedNative));

    const width = Math.max(croppedNative.width, js.width);
    const height = Math.max(croppedNative.height, js.height);
    const background = fixture.theme === "dark" ? [8, 10, 15, 255] : [255, 255, 255, 255];
    const nativePadded = padImage(croppedNative, width, height, background);
    const jsPadded = padImage(js, width, height, background);
    const diff = diffImages(nativePadded, jsPadded);
    const diffPath = path.join(paths.diffOutput, `${fixture.id}.png`);
    fs.writeFileSync(diffPath, encodePng(diff.image));

    const score = diff.meanAbsoluteError;
    results.push({
      id: fixture.id,
      name: fixture.name,
      threshold: fixture.threshold,
      score,
      passed: score <= fixture.threshold,
      nativeSize: { width: croppedNative.width, height: croppedNative.height },
      jsSize: { width: js.width, height: js.height },
      differingPixels: diff.differingPixels,
      totalPixels: diff.totalPixels,
      widget: fixture.widget,
      files: {
        native: path.relative(paths.swiftOutput, nativePath),
        nativeCrop: path.relative(paths.swiftCropOutput, croppedNativePath),
        js: path.relative(paths.jsOutput, jsPath),
        diff: path.relative(paths.diffOutput, diffPath),
      },
    });
  }

  return {
    generatedAt: new Date().toISOString(),
    results,
  };
}

async function runVisualReviews(report, paths, options) {
  const reviews = [];
  for (const result of report.results) {
    console.log(`Visual reviewing ${result.id} with ${options.visualModel}...`);
    reviews.push(await requestVisualReview(result, paths, options));
  }
  return reviews;
}

async function requestVisualReview(result, paths, options) {
  const widgetPayload = JSON.stringify(result.widget);
  const prompt = [
    "You are a strict but conservative visual parity judge for ChatKit widget rendering.",
    "Task:\nDetermine whether the ChatKitSwift native widget crop is visually on par with the chatkit-js reference crop for the same fixture.",
    [
      "Inputs:",
      "- Image 1: ChatKitSwift native crop.",
      "- Image 2: chatkit-js reference crop. This is the visual ground truth.",
      "- Image 3: diff heatmap. Brighter pixels indicate larger pixel differences, but the heatmap is only diagnostic evidence, not the final authority.",
      "- Fixture widget payload: source of truth for widget content, state, data, labels, actions, and semantic structure.",
    ].join("\n"),
    [
      "Ground truth rules:",
      "Use the JS reference image as the ground truth for realized visual appearance: layout, theme, spacing, typography scale, control styling, hierarchy, and visible rendering behavior.",
      "Use the fixture payload as ground truth for expected content and semantic structure.",
      "Do not infer expected styling from component names, fixture names, or design-system assumptions when the JS reference or payload shows otherwise.",
      "Do not penalize the Swift image for matching the JS reference even if both appear visually imperfect.",
    ].join("\n"),
    [
      "Evaluation scope:",
      "Compare the visible widget rendering only. Ignore surrounding contact-sheet labels, column headers, row titles, metadata, crop annotations, and background outside the widget crop.",
      "Compare Swift to JS directly before considering the diff heatmap.",
      "Use the diff heatmap to locate possible issues, but do not fail solely because the heatmap is bright.",
    ].join("\n"),
    "Decision labels:\nReturn exactly one of: pass, review, fail.",
    [
      "Pass:",
      "Return pass when the Swift crop preserves the same visible content, semantic hierarchy, layout intent, theme, control types, action styling, and approximate spacing as the JS reference.",
      "Accept minor differences from font rasterization, antialiasing, subpixel positioning, platform text rendering, shadow softness, border rasterization, and 1-2 px crop or padding drift.",
      "Accept small text wrapping differences only when all important content remains readable and the visual hierarchy is materially unchanged.",
    ].join("\n"),
    [
      "Review:",
      "Return review when there is a visible difference but it is ambiguous, low-severity, plausibly caused by crop size, font metrics, antialiasing, or expected platform rendering variance.",
      "Return review when the same apparent issue also exists in the JS reference.",
      "Return review when the diff is mostly text-edge noise, slight padding drift, shadow/border softness, or minor line-height variance.",
      "Return review when the evidence is insufficient to say with high confidence that Swift has a product-quality regression.",
    ].join("\n"),
    [
      "Fail:",
      "Return fail only for high-confidence product-quality regressions in Swift that are not present in the JS reference. Examples:",
      "- Missing, extra, or materially incorrect content.",
      "- Incorrect visible state, value, label, badge, action, icon, or control.",
      "- Wrong theme, background, color role, contrast, or emphasis that changes meaning.",
      "- Wrong control primitive, such as a toggle rendered as a checkbox, segmented control rendered as buttons, or native picker rendered unlike the JS reference.",
      "- Clipping, truncation, overlap, or compression that makes important content unreadable.",
      "- Material layout breakage: wrong grouping, wrong hierarchy, misplaced actions, collapsed sections, excessive spacing, or materially different alignment.",
      "- Incorrect enabled/disabled/selected/destructive/primary action styling.",
      "- Large size or crop mismatch that changes the visible widget content or intended layout.",
    ].join("\n"),
    [
      "Important calibration:",
      "Pixel metrics are advisory. A failed pixel check or high mean absolute error does not automatically mean fail.",
      "A passing pixel check does not automatically mean pass if there is a clear semantic or visual regression.",
      "Prefer pass over review for harmless rendering noise.",
      "Prefer review over fail unless the Swift-specific regression is clear and product-relevant.",
    ].join("\n"),
    [
      "Fixture metadata:",
      `Fixture: ${result.name} (${result.id})`,
      `Numeric mean absolute error: ${result.score.toFixed(4)}`,
      `Threshold: ${result.threshold.toFixed(4)}`,
      `Pixel check result: ${result.passed ? "pass" : "fail"}`,
      `Swift crop size: ${result.nativeSize.width}x${result.nativeSize.height}`,
      `JS crop size: ${result.jsSize.width}x${result.jsSize.height}`,
    ].join("\n"),
    `Fixture widget payload:\n${widgetPayload}`,
    [
      "Required output format:",
      "{",
      '  "verdict": "pass | review | fail",',
      '  "confidence": "low | medium | high",',
      '  "summary": "One concise sentence explaining the decision.",',
      '  "issues": [',
      "    {",
      '      "severity": "minor | moderate | major",',
      '      "category": "content | layout | theme | typography | controls | actions | clipping | spacing | crop | other",',
      '      "description": "Specific observed difference, if any.",',
      '      "swift_only": true',
      "    }",
      "  ],",
      '  "ignored_differences": [',
      '    "Differences intentionally ignored, such as antialiasing, subpixel drift, or text rasterization."',
      "  ]",
      "}",
    ].join("\n"),
    [
      "Output constraints:",
      "- Do not include markdown.",
      "- Do not mention component names as evidence unless the payload or image supports them.",
      "- Do not speculate about implementation causes.",
      "- Do not recommend fixes.",
      "- If verdict is pass, issues must be an empty array.",
      '- If verdict is fail, at least one issue must have severity "major" and swift_only true.',
    ].join("\n"),
  ].join("\n\n");

  const body = {
    model: options.visualModel,
    reasoning: { effort: "low" },
    input: [{
      role: "user",
      content: [
        { type: "input_text", text: prompt },
        { type: "input_image", image_url: imageDataURL(path.join(paths.swiftCropOutput, `${result.id}.png`)), detail: options.visualDetail },
        { type: "input_image", image_url: imageDataURL(path.join(paths.jsOutput, `${result.id}.png`)), detail: options.visualDetail },
        { type: "input_image", image_url: imageDataURL(path.join(paths.diffOutput, `${result.id}.png`)), detail: options.visualDetail },
      ],
    }],
    text: {
      verbosity: "low",
      format: VISUAL_REVIEW_RESPONSE_FORMAT,
    },
    max_output_tokens: 700,
  };

  const response = await fetch(RESPONSES_API_URL, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${process.env.OPENAI_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });
  const responseText = await response.text();
  if (!response.ok) {
    throw new Error(`Visual review failed for ${result.id}: HTTP ${response.status} ${responseText.slice(0, 500)}`);
  }

  let payload;
  try {
    payload = JSON.parse(responseText);
  } catch {
    payload = {};
  }
  const outputText = extractResponseText(payload) || responseText;
  const parsed = parseJSONish(outputText);
  return normalizeVisualReview(result, parsed, outputText, options);
}

function imageDataURL(filePath) {
  return `data:image/png;base64,${fs.readFileSync(filePath).toString("base64")}`;
}

function extractResponseText(payload) {
  if (typeof payload.output_text === "string") {
    return payload.output_text.trim();
  }

  const chunks = [];
  for (const item of payload.output || []) {
    if (typeof item.content === "string") {
      chunks.push(item.content);
    }
    for (const content of item.content || []) {
      if (typeof content.text === "string") {
        chunks.push(content.text);
      } else if (typeof content.value === "string") {
        chunks.push(content.value);
      }
    }
  }
  return chunks.join("\n").trim();
}

function parseJSONish(text) {
  const candidates = [text];
  const fenced = text.match(/```(?:json)?\s*([\s\S]*?)```/i);
  if (fenced) {
    candidates.push(fenced[1]);
  }
  const object = text.match(/\{[\s\S]*\}/);
  if (object) {
    candidates.push(object[0]);
  }

  for (const candidate of candidates) {
    try {
      const parsed = JSON.parse(candidate);
      if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) {
        return parsed;
      }
    } catch {
      // Try the next extraction strategy.
    }
  }
  return null;
}

function normalizeVisualReview(result, parsed, rawText, options) {
  const object = parsed || {};
  const verdict = normalizeChoice(object.verdict, ["pass", "fail", "review"], result.passed ? "pass" : "review");
  const confidence = normalizeChoice(object.confidence, ["low", "medium", "high"], "medium");
  return {
    id: result.id,
    name: result.name,
    model: options.visualModel,
    detail: options.visualDetail,
    verdict,
    confidence,
    summary: typeof object.summary === "string" && object.summary.trim()
      ? object.summary.trim()
      : "The visual model response could not be parsed into the expected summary.",
    issues: normalizeIssueArray(object.issues),
    ignoredDifferences: normalizeStringArray(object.ignored_differences),
    rawText: rawText.slice(0, 4000),
  };
}

function normalizeChoice(value, allowed, fallback) {
  if (typeof value !== "string") {
    return fallback;
  }
  const normalized = value.trim().toLowerCase();
  return allowed.includes(normalized) ? normalized : fallback;
}

function normalizeStringArray(value) {
  if (!Array.isArray(value)) {
    return [];
  }
  return value
    .map((entry) => String(entry).trim())
    .filter(Boolean)
    .slice(0, 8);
}

function normalizeIssueArray(value) {
  if (!Array.isArray(value)) {
    return [];
  }
  return value
    .map((entry) => {
      if (!entry || typeof entry !== "object" || Array.isArray(entry)) {
        return null;
      }
      const description = typeof entry.description === "string" ? entry.description.trim() : "";
      if (!description) {
        return null;
      }
      return {
        severity: normalizeChoice(entry.severity, ["minor", "moderate", "major"], "minor"),
        category: normalizeChoice(entry.category, ["content", "layout", "theme", "typography", "controls", "actions", "clipping", "spacing", "crop", "other"], "other"),
        description,
        swiftOnly: entry.swift_only === true,
      };
    })
    .filter(Boolean)
    .slice(0, 8);
}

function writeReport(report, outputRoot) {
  fs.writeFileSync(path.join(outputRoot, "report.json"), JSON.stringify(report, null, 2));
  const lines = [
    "# Widget Screenshot Parity",
    "",
    "| Fixture | Score | Threshold | Result | Native crop | JS crop |",
    "| --- | ---: | ---: | --- | --- | --- |",
  ];
  for (const result of report.results) {
    lines.push(`| ${result.name} | ${result.score.toFixed(4)} | ${result.threshold.toFixed(4)} | ${result.passed ? "pass" : "fail"} | ${result.nativeSize.width}x${result.nativeSize.height} | ${result.jsSize.width}x${result.jsSize.height} |`);
  }
  lines.push("");
  lines.push("Artifacts:");
  lines.push("");
  lines.push("- `swift/`: raw native SwiftUI fixture screenshots");
  lines.push("- `swift-crop/`: native screenshots cropped to visible widget content");
  lines.push("- `js/`: cropped real ChatKit JS widget screenshots");
  lines.push("- `diff/`: visual diff heatmaps");
  if (report.visualReviews && report.visualReviews.length > 0) {
    lines.push("");
    lines.push("## Visual Model Review");
    lines.push("");
    lines.push(`Model: \`${report.visualReview.model}\`; detail: \`${report.visualReview.detail}\`; reviewed at: \`${report.visualReview.reviewedAt}\`.`);
    lines.push("");
    lines.push("| Fixture | Verdict | Confidence | Summary |");
    lines.push("| --- | --- | --- | --- |");
    for (const review of report.visualReviews) {
      lines.push(`| ${markdownCell(review.name)} | ${review.verdict} | ${review.confidence} | ${markdownCell(review.summary)} |`);
    }
    for (const review of report.visualReviews) {
      if (review.issues.length === 0 && review.ignoredDifferences.length === 0) {
        continue;
      }
      lines.push("");
      lines.push(`### ${review.name}`);
      for (const issue of review.issues) {
        const swiftOnly = issue.swiftOnly ? "Swift-only" : "Shared/ambiguous";
        lines.push(`- Issue (${issue.severity}, ${issue.category}, ${swiftOnly}): ${issue.description}`);
      }
      for (const ignoredDifference of review.ignoredDifferences) {
        lines.push(`- Ignored: ${ignoredDifference}`);
      }
    }
  }
  fs.writeFileSync(path.join(outputRoot, "report.md"), `${lines.join("\n")}\n`);
}

function markdownCell(value) {
  return String(value).replace(/\|/g, "\\|").replace(/\s+/g, " ").trim();
}

function decodePng(buffer) {
  const signature = buffer.subarray(0, 8);
  if (!signature.equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]))) {
    throw new Error("Invalid PNG signature.");
  }

  let offset = 8;
  let width = 0;
  let height = 0;
  let colorType = 0;
  const idat = [];

  while (offset < buffer.length) {
    const length = buffer.readUInt32BE(offset);
    const type = buffer.subarray(offset + 4, offset + 8).toString("ascii");
    const data = buffer.subarray(offset + 8, offset + 8 + length);
    offset += 12 + length;

    if (type === "IHDR") {
      width = data.readUInt32BE(0);
      height = data.readUInt32BE(4);
      const bitDepth = data[8];
      colorType = data[9];
      if (bitDepth !== 8 || ![2, 6].includes(colorType)) {
        throw new Error(`Unsupported PNG format: bitDepth=${bitDepth} colorType=${colorType}`);
      }
    } else if (type === "IDAT") {
      idat.push(data);
    } else if (type === "IEND") {
      break;
    }
  }

  const channels = colorType === 6 ? 4 : 3;
  const raw = zlib.inflateSync(Buffer.concat(idat));
  const stride = width * channels;
  const rgba = Buffer.alloc(width * height * 4);
  let sourceOffset = 0;
  let previous = Buffer.alloc(stride);

  for (let y = 0; y < height; y += 1) {
    const filter = raw[sourceOffset++];
    const scanline = Buffer.from(raw.subarray(sourceOffset, sourceOffset + stride));
    sourceOffset += stride;
    unfilterScanline(scanline, previous, channels, filter);

    for (let x = 0; x < width; x += 1) {
      const source = x * channels;
      const target = (y * width + x) * 4;
      rgba[target] = scanline[source];
      rgba[target + 1] = scanline[source + 1];
      rgba[target + 2] = scanline[source + 2];
      rgba[target + 3] = channels === 4 ? scanline[source + 3] : 255;
    }
    previous = scanline;
  }

  return { width, height, data: rgba };
}

function unfilterScanline(line, previous, bytesPerPixel, filter) {
  for (let index = 0; index < line.length; index += 1) {
    const left = index >= bytesPerPixel ? line[index - bytesPerPixel] : 0;
    const up = previous[index] || 0;
    const upLeft = index >= bytesPerPixel ? previous[index - bytesPerPixel] || 0 : 0;
    let value = line[index];
    if (filter === 1) value = (value + left) & 0xff;
    if (filter === 2) value = (value + up) & 0xff;
    if (filter === 3) value = (value + Math.floor((left + up) / 2)) & 0xff;
    if (filter === 4) value = (value + paeth(left, up, upLeft)) & 0xff;
    if (filter > 4) throw new Error(`Unsupported PNG filter: ${filter}`);
    line[index] = value;
  }
}

function paeth(left, up, upLeft) {
  const estimate = left + up - upLeft;
  const leftDistance = Math.abs(estimate - left);
  const upDistance = Math.abs(estimate - up);
  const upLeftDistance = Math.abs(estimate - upLeft);
  if (leftDistance <= upDistance && leftDistance <= upLeftDistance) return left;
  if (upDistance <= upLeftDistance) return up;
  return upLeft;
}

function encodePng(image) {
  const raw = Buffer.alloc((image.width * 4 + 1) * image.height);
  for (let y = 0; y < image.height; y += 1) {
    const rowOffset = y * (image.width * 4 + 1);
    raw[rowOffset] = 0;
    image.data.copy(raw, rowOffset + 1, y * image.width * 4, (y + 1) * image.width * 4);
  }

  const header = Buffer.alloc(13);
  header.writeUInt32BE(image.width, 0);
  header.writeUInt32BE(image.height, 4);
  header[8] = 8;
  header[9] = 6;
  header[10] = 0;
  header[11] = 0;
  header[12] = 0;

  return Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    pngChunk("IHDR", header),
    pngChunk("IDAT", zlib.deflateSync(raw)),
    pngChunk("IEND", Buffer.alloc(0)),
  ]);
}

function pngChunk(type, data) {
  const typeBuffer = Buffer.from(type, "ascii");
  const length = Buffer.alloc(4);
  length.writeUInt32BE(data.length, 0);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(Buffer.concat([typeBuffer, data])), 0);
  return Buffer.concat([length, typeBuffer, data, crc]);
}

const crcTable = (() => {
  const table = new Uint32Array(256);
  for (let n = 0; n < 256; n += 1) {
    let c = n;
    for (let k = 0; k < 8; k += 1) {
      c = (c & 1) ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    }
    table[n] = c >>> 0;
  }
  return table;
})();

function crc32(buffer) {
  let crc = 0xffffffff;
  for (const byte of buffer) {
    crc = crcTable[(crc ^ byte) & 0xff] ^ (crc >>> 8);
  }
  return (crc ^ 0xffffffff) >>> 0;
}

function contentBounds(image, background, tolerance) {
  let minX = image.width;
  let minY = image.height;
  let maxX = -1;
  let maxY = -1;

  for (let y = 0; y < image.height; y += 1) {
    for (let x = 0; x < image.width; x += 1) {
      const offset = (y * image.width + x) * 4;
      const delta = Math.max(
        Math.abs(image.data[offset] - background[0]),
        Math.abs(image.data[offset + 1] - background[1]),
        Math.abs(image.data[offset + 2] - background[2]),
        Math.abs(image.data[offset + 3] - background[3]),
      );
      if (delta > tolerance) {
        minX = Math.min(minX, x);
        minY = Math.min(minY, y);
        maxX = Math.max(maxX, x);
        maxY = Math.max(maxY, y);
      }
    }
  }

  if (maxX < minX || maxY < minY) {
    return { x: 0, y: 0, width: image.width, height: image.height };
  }

  return {
    x: Math.max(0, minX - 2),
    y: Math.max(0, minY - 2),
    width: Math.min(image.width - Math.max(0, minX - 2), maxX - minX + 5),
    height: Math.min(image.height - Math.max(0, minY - 2), maxY - minY + 5),
  };
}

function firstContentClusterBounds(image, background, tolerance, maxGap) {
  const rows = [];
  for (let y = 0; y < image.height; y += 1) {
    let rowHasContent = false;
    for (let x = 0; x < image.width; x += 1) {
      const offset = (y * image.width + x) * 4;
      const delta = Math.max(
        Math.abs(image.data[offset] - background[0]),
        Math.abs(image.data[offset + 1] - background[1]),
        Math.abs(image.data[offset + 2] - background[2]),
        Math.abs(image.data[offset + 3] - background[3]),
      );
      if (delta > tolerance) {
        rowHasContent = true;
        break;
      }
    }
    if (rowHasContent) rows.push(y);
  }

  if (rows.length === 0) {
    return { x: 0, y: 0, width: image.width, height: image.height };
  }

  let startY = rows[0];
  let endY = rows[0];
  for (let index = 1; index < rows.length; index += 1) {
    if (rows[index] - endY > maxGap) {
      break;
    }
    endY = rows[index];
  }

  let minX = image.width;
  let maxX = -1;
  for (let y = startY; y <= endY; y += 1) {
    for (let x = 0; x < image.width; x += 1) {
      const offset = (y * image.width + x) * 4;
      const delta = Math.max(
        Math.abs(image.data[offset] - background[0]),
        Math.abs(image.data[offset + 1] - background[1]),
        Math.abs(image.data[offset + 2] - background[2]),
        Math.abs(image.data[offset + 3] - background[3]),
      );
      if (delta > tolerance) {
        minX = Math.min(minX, x);
        maxX = Math.max(maxX, x);
      }
    }
  }

  if (maxX < minX) {
    return { x: 0, y: 0, width: image.width, height: endY - startY + 1 };
  }

  const x = Math.max(0, minX - 2);
  const y = Math.max(0, startY - 2);
  return {
    x,
    y,
    width: Math.min(image.width - x, maxX - minX + 5),
    height: Math.min(image.height - y, endY - startY + 5),
  };
}

function cropImage(image, bounds) {
  const data = Buffer.alloc(bounds.width * bounds.height * 4);
  for (let y = 0; y < bounds.height; y += 1) {
    const sourceStart = ((bounds.y + y) * image.width + bounds.x) * 4;
    const targetStart = y * bounds.width * 4;
    image.data.copy(data, targetStart, sourceStart, sourceStart + bounds.width * 4);
  }
  return { width: bounds.width, height: bounds.height, data };
}

function padImage(image, width, height, background) {
  const data = Buffer.alloc(width * height * 4);
  for (let index = 0; index < width * height; index += 1) {
    data[index * 4] = background[0];
    data[index * 4 + 1] = background[1];
    data[index * 4 + 2] = background[2];
    data[index * 4 + 3] = background[3];
  }
  for (let y = 0; y < image.height; y += 1) {
    const sourceStart = y * image.width * 4;
    const targetStart = y * width * 4;
    image.data.copy(data, targetStart, sourceStart, sourceStart + image.width * 4);
  }
  return { width, height, data };
}

function diffImages(left, right) {
  if (left.width !== right.width || left.height !== right.height) {
    throw new Error("Images must have matching dimensions before diffing.");
  }

  const data = Buffer.alloc(left.width * left.height * 4);
  let sum = 0;
  let differingPixels = 0;
  const totalPixels = left.width * left.height;

  for (let index = 0; index < totalPixels; index += 1) {
    const offset = index * 4;
    const dr = Math.abs(left.data[offset] - right.data[offset]);
    const dg = Math.abs(left.data[offset + 1] - right.data[offset + 1]);
    const db = Math.abs(left.data[offset + 2] - right.data[offset + 2]);
    const da = Math.abs(left.data[offset + 3] - right.data[offset + 3]);
    const max = Math.max(dr, dg, db, da);
    if (max > 24) differingPixels += 1;
    sum += dr + dg + db + da;
    data[offset] = Math.min(255, dr * 3);
    data[offset + 1] = Math.min(255, dg * 3);
    data[offset + 2] = Math.min(255, db * 3);
    data[offset + 3] = 255;
  }

  return {
    image: { width: left.width, height: left.height, data },
    meanAbsoluteError: sum / (totalPixels * 4 * 255),
    differingPixels,
    totalPixels,
  };
}
