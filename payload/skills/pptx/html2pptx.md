# HTML to PowerPoint Guide

Convert HTML slides to PowerPoint presentations with accurate positioning using the `html2pptx.js` library.

---

## 🗂️ 图片追踪 Manifest（必读：每次编辑 PPT 前）

**PPT 工作流中，图片会反复替换。每次开始任何 PPT 编辑任务，必须先执行以下步骤：**

### Manifest 存放目录（固定，不可变）

```
~/Desktop/CodePilot/ppt-manifests/
```

**命名规范：** `[项目名]-manifest.json`
例：`my-project-manifest.json`

> ⚠️ 禁止把 manifest 存到 ~/Downloads 或其他临时目录，Downloads 会被定期清理。

### 第一步：查找并读取 Manifest

```bash
# 所有 manifest 统一存放在此目录
ls ~/Desktop/CodePilot/ppt-manifests/
```

如果 manifest 存在，**必须先读取**，以确认每页当前使用的图片。

### Manifest 格式

```json
{
  "_comment": "PPT 图片追踪 Manifest — 每次替换图片后自动更新此文件",
  "project": "项目名",
  "current_version": "v6",
  "current_file": "/path/to/current.pptx",
  "total_slides": 33,
  "last_updated": "2026-04-05",
  "image_dirs": {
    "uploads": "~/Desktop/CodePilot/.codepilot-uploads",
    "generated": "~/Desktop/CodePilot/Bridge/.codepilot-images"
  },
  "slides": {
    "4": {
      "image_file": "/full/path/to/image.jpg",
      "description": "双轴时间线：技术加速与文明长河",
      "updated_at": "2026-04-05",
      "updated_in_version": "v6"
    }
  },
  "history": [
    {
      "version": "v6",
      "date": "2026-04-05",
      "changes": [
        { "slide": 4, "new_image": "filename.jpg", "desc": "图片描述" }
      ]
    }
  ]
}
```

### 第二步：替换图片后立即更新 Manifest

每次用户确认新图片后，**在生成新版本 PPTX 之前**，先用下面的脚本更新 manifest：

```python
import json, os
from datetime import datetime

manifest_path = os.path.expanduser('~/Desktop/CodePilot/ppt-manifests/[项目名]-manifest.json')
with open(manifest_path, 'r', encoding='utf-8') as f:
    manifest = json.load(f)

new_version = 'v7'  # 递增版本号
new_changes = []

# 记录每个替换
replacements = {
    4: {'file': 'xxx.jpg', 'desc': '图片描述'},
}
for slide_num, info in replacements.items():
    full_path = os.path.join(manifest['image_dirs']['uploads'], info['file'])
    manifest['slides'][str(slide_num)] = {
        'image_file': full_path,
        'description': info['desc'],
        'source_dir': manifest['image_dirs']['uploads'],
        'updated_at': datetime.now().strftime('%Y-%m-%d'),
        'updated_in_version': new_version,
    }
    new_changes.append({'slide': slide_num, 'new_image': info['file'], 'desc': info['desc']})

manifest['current_version'] = new_version
manifest['current_file'] = os.path.expanduser(f'~/Downloads/[项目名]-{new_version}.pptx')  # PPTX 仍输出到 Downloads，只有 manifest 在 ppt-manifests/
manifest['last_updated'] = datetime.now().strftime('%Y-%m-%d')
manifest['history'].append({'version': new_version, 'date': manifest['last_updated'], 'changes': new_changes})

with open(manifest_path, 'w', encoding='utf-8') as f:
    json.dump(manifest, f, ensure_ascii=False, indent=2)
print(f"✅ Manifest 已更新至 {new_version}")
```

### 第三步：初次建立 Manifest（新项目）

当一个 PPT 项目第一次被编辑时，如果没有 manifest，用以下脚本从现有 PPTX 提取图片状态：

```python
import json, os
from pptx import Presentation
from pptx.enum.shapes import MSO_SHAPE_TYPE

A_NS = '{http://schemas.openxmlformats.org/drawingml/2006/main}'
R_NS = '{http://schemas.openxmlformats.org/officeDocument/2006/relationships}'

pptx_path = '~/Downloads/[项目名].pptx'
prs = Presentation(os.path.expanduser(pptx_path))

slides_map = {}
for i, slide in enumerate(prs.slides):
    pic_shapes = [s for s in slide.shapes if s.shape_type == MSO_SHAPE_TYPE.PICTURE]
    if not pic_shapes:
        continue
    pic_shapes.sort(key=lambda s: s.width * s.height, reverse=True)
    shape = pic_shapes[0]
    blip = shape._pic.find(f'.//{A_NS}blip')
    if blip is None:
        continue
    rId = blip.get(f'{R_NS}embed')
    image_part = slide.part.related_part(rId)
    slides_map[str(i + 1)] = {
        'image_file': None,  # 首次建立时未知源文件路径
        'description': '',
        'file_size_kb': len(image_part._blob) // 1024,
        'updated_at': '初始状态',
        'updated_in_version': 'v1',
    }

manifest = {
    '_comment': 'PPT 图片追踪 Manifest',
    'project': '[项目名]',
    'current_version': 'v1',
    'current_file': os.path.expanduser(pptx_path),
    'total_slides': len(prs.slides),
    'last_updated': '2026-xx-xx',
    'image_dirs': {
        'uploads': os.path.expanduser('~/Desktop/CodePilot/.codepilot-uploads'),
        'generated': os.path.expanduser('~/Desktop/CodePilot/Bridge/.codepilot-images'),
    },
    'slides': slides_map,
    'history': []
}

import re
project_name = re.sub(r'-v\d+$', '', os.path.basename(pptx_path).replace('.pptx', ''))
manifest_path = os.path.expanduser(f'~/Desktop/CodePilot/ppt-manifests/{project_name}-manifest.json')
with open(manifest_path, 'w', encoding='utf-8') as f:
    json.dump(manifest, f, ensure_ascii=False, indent=2)
print(f"✅ Manifest 初始化完成")
```

### 铁律

| 时机 | 动作 |
|------|------|
| 开始 PPT 编辑任务 | 先读 manifest，确认各页当前图片 |
| 用户发送替换图片 | 立即记录，等所有替换确认完毕后批量更新 manifest |
| 生成新版本 PPTX | 从 manifest 读取每页图片路径，而不是凭记忆 |
| 新版本生成完成 | 更新 manifest 的 `current_version` 和 `current_file` |

---

## Table of Contents

1. [Creating HTML Slides](#creating-html-slides)
2. [Using the html2pptx Library](#using-the-html2pptx-library)
3. [Using PptxGenJS](#using-pptxgenjs)

---

## Creating HTML Slides

Every HTML slide must include proper body dimensions:

### Layout Dimensions

- **16:9** (default): `width: 720pt; height: 405pt`
- **4:3**: `width: 720pt; height: 540pt`
- **16:10**: `width: 720pt; height: 450pt`

### Supported Elements

- `<p>`, `<h1>`-`<h6>` - Text with styling
- `<ul>`, `<ol>` - Lists (never use manual bullets •, -, *)
- `<b>`, `<strong>` - Bold text (inline formatting)
- `<i>`, `<em>` - Italic text (inline formatting)
- `<u>` - Underlined text (inline formatting)
- `<span>` - Inline formatting with CSS styles (bold, italic, underline, color)
- `<br>` - Line breaks
- `<div>` with bg/border - Becomes shape
- `<img>` - Images
- `class="placeholder"` - Reserved space for charts (returns `{ id, x, y, w, h }`)

### Critical Text Rules

**ALL text MUST be inside `<p>`, `<h1>`-`<h6>`, `<ul>`, or `<ol>` tags:**
- ✅ Correct: `<div><p>Text here</p></div>`
- ❌ Wrong: `<div>Text here</div>` - **Text will NOT appear in PowerPoint**
- ❌ Wrong: `<span>Text</span>` - **Text will NOT appear in PowerPoint**
- Text in `<div>` or `<span>` without a text tag will be silently ignored

**NEVER use manual bullet symbols (•, -, *, etc.)** - Use `<ul>` or `<ol>` lists instead

**ONLY use web-safe fonts that are universally available:**
- ✅ Web-safe fonts: `Arial`, `Helvetica`, `Times New Roman`, `Georgia`, `Courier New`, `Verdana`, `Tahoma`, `Trebuchet MS`, `Impact`, `Comic Sans MS`
- ❌ Wrong: `'Segoe UI'`, `'SF Pro'`, `'Roboto'`, custom fonts - **Might cause rendering issues**

### Styling

- Use `display: flex` on body to prevent margin collapse from breaking overflow validation
- Use `margin` for spacing (padding included in size)
- Inline formatting: Use `<b>`, `<i>`, `<u>` tags OR `<span>` with CSS styles
  - `<span>` supports: `font-weight: bold`, `font-style: italic`, `text-decoration: underline`, `color: #rrggbb`
  - `<span>` does NOT support: `margin`, `padding` (not supported in PowerPoint text runs)
  - Example: `<span style="font-weight: bold; color: #667eea;">Bold blue text</span>`
- Flexbox works - positions calculated from rendered layout
- Use hex colors with `#` prefix in CSS
- **Text alignment**: Use CSS `text-align` (`center`, `right`, etc.) when needed as a hint to PptxGenJS for text formatting if text lengths are slightly off

### Shape Styling (DIV elements only)

**IMPORTANT: Backgrounds, borders, and shadows only work on `<div>` elements, NOT on text elements (`<p>`, `<h1>`-`<h6>`, `<ul>`, `<ol>`)**

- **Backgrounds**: CSS `background` or `background-color` on `<div>` elements only
  - Example: `<div style="background: #f0f0f0;">` - Creates a shape with background
- **Borders**: CSS `border` on `<div>` elements converts to PowerPoint shape borders
  - Supports uniform borders: `border: 2px solid #333333`
  - Supports partial borders: `border-left`, `border-right`, `border-top`, `border-bottom` (rendered as line shapes)
  - Example: `<div style="border-left: 8pt solid #E76F51;">`
- **Border radius**: CSS `border-radius` on `<div>` elements for rounded corners
  - `border-radius: 50%` or higher creates circular shape
  - Percentages <50% calculated relative to shape's smaller dimension
  - Supports px and pt units (e.g., `border-radius: 8pt;`, `border-radius: 12px;`)
  - Example: `<div style="border-radius: 25%;">` on 100x200px box = 25% of 100px = 25px radius
- **Box shadows**: CSS `box-shadow` on `<div>` elements converts to PowerPoint shadows
  - Supports outer shadows only (inset shadows are ignored to prevent corruption)
  - Example: `<div style="box-shadow: 2px 2px 8px rgba(0, 0, 0, 0.3);">`
  - Note: Inset/inner shadows are not supported by PowerPoint and will be skipped

### Icons & Gradients

- **CRITICAL: Never use CSS gradients (`linear-gradient`, `radial-gradient`)** - They don't convert to PowerPoint
- **ALWAYS create gradient/icon PNGs FIRST using Sharp, then reference in HTML**
- For gradients: Rasterize SVG to PNG background images
- For icons: Rasterize react-icons SVG to PNG images
- All visual effects must be pre-rendered as raster images before HTML rendering

**Rasterizing Icons with Sharp:**

```javascript
const React = require('react');
const ReactDOMServer = require('react-dom/server');
const sharp = require('sharp');
const { FaHome } = require('react-icons/fa');

async function rasterizeIconPng(IconComponent, color, size = "256", filename) {
  const svgString = ReactDOMServer.renderToStaticMarkup(
    React.createElement(IconComponent, { color: `#${color}`, size: size })
  );

  // Convert SVG to PNG using Sharp
  await sharp(Buffer.from(svgString))
    .png()
    .toFile(filename);

  return filename;
}

// Usage: Rasterize icon before using in HTML
const iconPath = await rasterizeIconPng(FaHome, "4472c4", "256", "home-icon.png");
// Then reference in HTML: <img src="home-icon.png" style="width: 40pt; height: 40pt;">
```

**Rasterizing Gradients with Sharp:**

```javascript
const sharp = require('sharp');

async function createGradientBackground(filename) {
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="1000" height="562.5">
    <defs>
      <linearGradient id="g" x1="0%" y1="0%" x2="100%" y2="100%">
        <stop offset="0%" style="stop-color:#COLOR1"/>
        <stop offset="100%" style="stop-color:#COLOR2"/>
      </linearGradient>
    </defs>
    <rect width="100%" height="100%" fill="url(#g)"/>
  </svg>`;

  await sharp(Buffer.from(svg))
    .png()
    .toFile(filename);

  return filename;
}

// Usage: Create gradient background before HTML
const bgPath = await createGradientBackground("gradient-bg.png");
// Then in HTML: <body style="background-image: url('gradient-bg.png');">
```

### Example

```html
<!DOCTYPE html>
<html>
<head>
<style>
html { background: #ffffff; }
body {
  width: 720pt; height: 405pt; margin: 0; padding: 0;
  background: #f5f5f5; font-family: Arial, sans-serif;
  display: flex;
}
.content { margin: 30pt; padding: 40pt; background: #ffffff; border-radius: 8pt; }
h1 { color: #2d3748; font-size: 32pt; }
.box {
  background: #70ad47; padding: 20pt; border: 3px solid #5a8f37;
  border-radius: 12pt; box-shadow: 3px 3px 10px rgba(0, 0, 0, 0.25);
}
</style>
</head>
<body>
<div class="content">
  <h1>Recipe Title</h1>
  <ul>
    <li><b>Item:</b> Description</li>
  </ul>
  <p>Text with <b>bold</b>, <i>italic</i>, <u>underline</u>.</p>
  <div id="chart" class="placeholder" style="width: 350pt; height: 200pt;"></div>

  <!-- Text MUST be in <p> tags -->
  <div class="box">
    <p>5</p>
  </div>
</div>
</body>
</html>
```

## Using the html2pptx Library

### Dependencies

These libraries have been globally installed and are available to use:
- `pptxgenjs`
- `playwright`
- `sharp`

### Basic Usage

```javascript
const pptxgen = require('pptxgenjs');
const html2pptx = require('./html2pptx');

const pptx = new pptxgen();
pptx.layout = 'LAYOUT_16x9';  // Must match HTML body dimensions

const { slide, placeholders } = await html2pptx('slide1.html', pptx);

// Add chart to placeholder area
if (placeholders.length > 0) {
    slide.addChart(pptx.charts.LINE, chartData, placeholders[0]);
}

await pptx.writeFile('output.pptx');
```

### API Reference

#### Function Signature
```javascript
await html2pptx(htmlFile, pres, options)
```

#### Parameters
- `htmlFile` (string): Path to HTML file (absolute or relative)
- `pres` (pptxgen): PptxGenJS presentation instance with layout already set
- `options` (object, optional):
  - `tmpDir` (string): Temporary directory for generated files (default: `process.env.TMPDIR || '/tmp'`)
  - `slide` (object): Existing slide to reuse (default: creates new slide)

#### Returns
```javascript
{
    slide: pptxgenSlide,           // The created/updated slide
    placeholders: [                 // Array of placeholder positions
        { id: string, x: number, y: number, w: number, h: number },
        ...
    ]
}
```

### Validation

The library automatically validates and collects all errors before throwing:

1. **HTML dimensions must match presentation layout** - Reports dimension mismatches
2. **Content must not overflow body** - Reports overflow with exact measurements
3. **CSS gradients** - Reports unsupported gradient usage
4. **Text element styling** - Reports backgrounds/borders/shadows on text elements (only allowed on divs)

**All validation errors are collected and reported together** in a single error message, allowing you to fix all issues at once instead of one at a time.

### Working with Placeholders

```javascript
const { slide, placeholders } = await html2pptx('slide.html', pptx);

// Use first placeholder
slide.addChart(pptx.charts.BAR, data, placeholders[0]);

// Find by ID
const chartArea = placeholders.find(p => p.id === 'chart-area');
slide.addChart(pptx.charts.LINE, data, chartArea);
```

### Complete Example

```javascript
const pptxgen = require('pptxgenjs');
const html2pptx = require('./html2pptx');

async function createPresentation() {
    const pptx = new pptxgen();
    pptx.layout = 'LAYOUT_16x9';
    pptx.author = 'Your Name';
    pptx.title = 'My Presentation';

    // Slide 1: Title
    const { slide: slide1 } = await html2pptx('slides/title.html', pptx);

    // Slide 2: Content with chart
    const { slide: slide2, placeholders } = await html2pptx('slides/data.html', pptx);

    const chartData = [{
        name: 'Sales',
        labels: ['Q1', 'Q2', 'Q3', 'Q4'],
        values: [4500, 5500, 6200, 7100]
    }];

    slide2.addChart(pptx.charts.BAR, chartData, {
        ...placeholders[0],
        showTitle: true,
        title: 'Quarterly Sales',
        showCatAxisTitle: true,
        catAxisTitle: 'Quarter',
        showValAxisTitle: true,
        valAxisTitle: 'Sales ($000s)'
    });

    // Save
    await pptx.writeFile({ fileName: 'presentation.pptx' });
    console.log('Presentation created successfully!');
}

createPresentation().catch(console.error);
```

## Using PptxGenJS

After converting HTML to slides with `html2pptx`, you'll use PptxGenJS to add dynamic content like charts, images, and additional elements.

### ⚠️ Critical Rules

#### Colors
- **NEVER use `#` prefix** with hex colors in PptxGenJS - causes file corruption
- ✅ Correct: `color: "FF0000"`, `fill: { color: "0066CC" }`
- ❌ Wrong: `color: "#FF0000"` (breaks document)

### Adding Images

Always calculate aspect ratios from actual image dimensions:

```javascript
// Get image dimensions: identify image.png | grep -o '[0-9]* x [0-9]*'
const imgWidth = 1860, imgHeight = 1519;  // From actual file
const aspectRatio = imgWidth / imgHeight;

const h = 3;  // Max height
const w = h * aspectRatio;
const x = (10 - w) / 2;  // Center on 16:9 slide

slide.addImage({ path: "chart.png", x, y: 1.5, w, h });
```

### Adding Text

```javascript
// Rich text with formatting
slide.addText([
    { text: "Bold ", options: { bold: true } },
    { text: "Italic ", options: { italic: true } },
    { text: "Normal" }
], {
    x: 1, y: 2, w: 8, h: 1
});
```

### Adding Shapes

```javascript
// Rectangle
slide.addShape(pptx.shapes.RECTANGLE, {
    x: 1, y: 1, w: 3, h: 2,
    fill: { color: "4472C4" },
    line: { color: "000000", width: 2 }
});

// Circle
slide.addShape(pptx.shapes.OVAL, {
    x: 5, y: 1, w: 2, h: 2,
    fill: { color: "ED7D31" }
});

// Rounded rectangle
slide.addShape(pptx.shapes.ROUNDED_RECTANGLE, {
    x: 1, y: 4, w: 3, h: 1.5,
    fill: { color: "70AD47" },
    rectRadius: 0.2
});
```

### Adding Charts

**Required for most charts:** Axis labels using `catAxisTitle` (category) and `valAxisTitle` (value).

**Chart Data Format:**
- Use **single series with all labels** for simple bar/line charts
- Each series creates a separate legend entry
- Labels array defines X-axis values

**Time Series Data - Choose Correct Granularity:**
- **< 30 days**: Use daily grouping (e.g., "10-01", "10-02") - avoid monthly aggregation that creates single-point charts
- **30-365 days**: Use monthly grouping (e.g., "2024-01", "2024-02")
- **> 365 days**: Use yearly grouping (e.g., "2023", "2024")
- **Validate**: Charts with only 1 data point likely indicate incorrect aggregation for the time period

```javascript
const { slide, placeholders } = await html2pptx('slide.html', pptx);

// CORRECT: Single series with all labels
slide.addChart(pptx.charts.BAR, [{
    name: "Sales 2024",
    labels: ["Q1", "Q2", "Q3", "Q4"],
    values: [4500, 5500, 6200, 7100]
}], {
    ...placeholders[0],  // Use placeholder position
    barDir: 'col',       // 'col' = vertical bars, 'bar' = horizontal
    showTitle: true,
    title: 'Quarterly Sales',
    showLegend: false,   // No legend needed for single series
    // Required axis labels
    showCatAxisTitle: true,
    catAxisTitle: 'Quarter',
    showValAxisTitle: true,
    valAxisTitle: 'Sales ($000s)',
    // Optional: Control scaling (adjust min based on data range for better visualization)
    valAxisMaxVal: 8000,
    valAxisMinVal: 0,  // Use 0 for counts/amounts; for clustered data (e.g., 4500-7100), consider starting closer to min value
    valAxisMajorUnit: 2000,  // Control y-axis label spacing to prevent crowding
    catAxisLabelRotate: 45,  // Rotate labels if crowded
    dataLabelPosition: 'outEnd',
    dataLabelColor: '000000',
    // Use single color for single-series charts
    chartColors: ["4472C4"]  // All bars same color
});
```

#### Scatter Chart

**IMPORTANT**: Scatter chart data format is unusual - first series contains X-axis values, subsequent series contain Y-values:

```javascript
// Prepare data
const data1 = [{ x: 10, y: 20 }, { x: 15, y: 25 }, { x: 20, y: 30 }];
const data2 = [{ x: 12, y: 18 }, { x: 18, y: 22 }];

const allXValues = [...data1.map(d => d.x), ...data2.map(d => d.x)];

slide.addChart(pptx.charts.SCATTER, [
    { name: 'X-Axis', values: allXValues },  // First series = X values
    { name: 'Series 1', values: data1.map(d => d.y) },  // Y values only
    { name: 'Series 2', values: data2.map(d => d.y) }   // Y values only
], {
    x: 1, y: 1, w: 8, h: 4,
    lineSize: 0,  // 0 = no connecting lines
    lineDataSymbol: 'circle',
    lineDataSymbolSize: 6,
    showCatAxisTitle: true,
    catAxisTitle: 'X Axis',
    showValAxisTitle: true,
    valAxisTitle: 'Y Axis',
    chartColors: ["4472C4", "ED7D31"]
});
```

#### Line Chart

```javascript
slide.addChart(pptx.charts.LINE, [{
    name: "Temperature",
    labels: ["Jan", "Feb", "Mar", "Apr"],
    values: [32, 35, 42, 55]
}], {
    x: 1, y: 1, w: 8, h: 4,
    lineSize: 4,
    lineSmooth: true,
    // Required axis labels
    showCatAxisTitle: true,
    catAxisTitle: 'Month',
    showValAxisTitle: true,
    valAxisTitle: 'Temperature (°F)',
    // Optional: Y-axis range (set min based on data range for better visualization)
    valAxisMinVal: 0,     // For ranges starting at 0 (counts, percentages, etc.)
    valAxisMaxVal: 60,
    valAxisMajorUnit: 20,  // Control y-axis label spacing to prevent crowding (e.g., 10, 20, 25)
    // valAxisMinVal: 30,  // PREFERRED: For data clustered in a range (e.g., 32-55 or ratings 3-5), start axis closer to min value to show variation
    // Optional: Chart colors
    chartColors: ["4472C4", "ED7D31", "A5A5A5"]
});
```

#### Pie Chart (No Axis Labels Required)

**CRITICAL**: Pie charts require a **single data series** with all categories in the `labels` array and corresponding values in the `values` array.

```javascript
slide.addChart(pptx.charts.PIE, [{
    name: "Market Share",
    labels: ["Product A", "Product B", "Other"],  // All categories in one array
    values: [35, 45, 20]  // All values in one array
}], {
    x: 2, y: 1, w: 6, h: 4,
    showPercent: true,
    showLegend: true,
    legendPos: 'r',  // right
    chartColors: ["4472C4", "ED7D31", "A5A5A5"]
});
```

#### Multiple Data Series

```javascript
slide.addChart(pptx.charts.LINE, [
    {
        name: "Product A",
        labels: ["Q1", "Q2", "Q3", "Q4"],
        values: [10, 20, 30, 40]
    },
    {
        name: "Product B",
        labels: ["Q1", "Q2", "Q3", "Q4"],
        values: [15, 25, 20, 35]
    }
], {
    x: 1, y: 1, w: 8, h: 4,
    showCatAxisTitle: true,
    catAxisTitle: 'Quarter',
    showValAxisTitle: true,
    valAxisTitle: 'Revenue ($M)'
});
```

### Chart Colors

**CRITICAL**: Use hex colors **without** the `#` prefix - including `#` causes file corruption.

**Align chart colors with your chosen design palette**, ensuring sufficient contrast and distinctiveness for data visualization. Adjust colors for:
- Strong contrast between adjacent series
- Readability against slide backgrounds
- Accessibility (avoid red-green only combinations)

```javascript
// Example: Ocean palette-inspired chart colors (adjusted for contrast)
const chartColors = ["16A085", "FF6B9D", "2C3E50", "F39C12", "9B59B6"];

// Single-series chart: Use one color for all bars/points
slide.addChart(pptx.charts.BAR, [{
    name: "Sales",
    labels: ["Q1", "Q2", "Q3", "Q4"],
    values: [4500, 5500, 6200, 7100]
}], {
    ...placeholders[0],
    chartColors: ["16A085"],  // All bars same color
    showLegend: false
});

// Multi-series chart: Each series gets a different color
slide.addChart(pptx.charts.LINE, [
    { name: "Product A", labels: ["Q1", "Q2", "Q3"], values: [10, 20, 30] },
    { name: "Product B", labels: ["Q1", "Q2", "Q3"], values: [15, 25, 20] }
], {
    ...placeholders[0],
    chartColors: ["16A085", "FF6B9D"]  // One color per series
});
```

### Adding Tables

Tables can be added with basic or advanced formatting:

#### Basic Table

```javascript
slide.addTable([
    ["Header 1", "Header 2", "Header 3"],
    ["Row 1, Col 1", "Row 1, Col 2", "Row 1, Col 3"],
    ["Row 2, Col 1", "Row 2, Col 2", "Row 2, Col 3"]
], {
    x: 0.5,
    y: 1,
    w: 9,
    h: 3,
    border: { pt: 1, color: "999999" },
    fill: { color: "F1F1F1" }
});
```

#### Table with Custom Formatting

```javascript
const tableData = [
    // Header row with custom styling
    [
        { text: "Product", options: { fill: { color: "4472C4" }, color: "FFFFFF", bold: true } },
        { text: "Revenue", options: { fill: { color: "4472C4" }, color: "FFFFFF", bold: true } },
        { text: "Growth", options: { fill: { color: "4472C4" }, color: "FFFFFF", bold: true } }
    ],
    // Data rows
    ["Product A", "$50M", "+15%"],
    ["Product B", "$35M", "+22%"],
    ["Product C", "$28M", "+8%"]
];

slide.addTable(tableData, {
    x: 1,
    y: 1.5,
    w: 8,
    h: 3,
    colW: [3, 2.5, 2.5],  // Column widths
    rowH: [0.5, 0.6, 0.6, 0.6],  // Row heights
    border: { pt: 1, color: "CCCCCC" },
    align: "center",
    valign: "middle",
    fontSize: 14
});
```

#### Table with Merged Cells

```javascript
const mergedTableData = [
    [
        { text: "Q1 Results", options: { colspan: 3, fill: { color: "4472C4" }, color: "FFFFFF", bold: true } }
    ],
    ["Product", "Sales", "Market Share"],
    ["Product A", "$25M", "35%"],
    ["Product B", "$18M", "25%"]
];

slide.addTable(mergedTableData, {
    x: 1,
    y: 1,
    w: 8,
    h: 2.5,
    colW: [3, 2.5, 2.5],
    border: { pt: 1, color: "DDDDDD" }
});
```

### Table Options

Common table options:
- `x, y, w, h` - Position and size
- `colW` - Array of column widths (in inches)
- `rowH` - Array of row heights (in inches)
- `border` - Border style: `{ pt: 1, color: "999999" }`
- `fill` - Background color (no # prefix)
- `align` - Text alignment: "left", "center", "right"
- `valign` - Vertical alignment: "top", "middle", "bottom"
- `fontSize` - Text size
- `autoPage` - Auto-create new slides if content overflows