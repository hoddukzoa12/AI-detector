---
name: infocutter-thumbnail-generator
description: Generate Infocutter blog thumbnail images. Use when creating or replacing thumbnails for vibecode-chrome-extension-infocutter/introduce/blog posts, especially text-free 4:3 emotional editorial illustrations inspired by the provided Infocutter reference image.
---

# Infocutter Thumbnail Generator

Create blog thumbnails for Infocutter posts with the built-in `imagegen` skill/tool.

## Output Rules

- Use generated bitmap images, not SVG or code-rendered placeholders.
- Aspect ratio must be landscape `4:3`.
- Final workspace copies should be PNG, preferably normalized to `1200x900`.
- Save one image per numbered Markdown post using the same basename:
  `introduce/blog/images/NN-post-slug.png`.
- Do not include visible text: no Korean, English, numbers, labels, logos, UI words, watermarks, or title areas.
- Blank UI cards, abstract lines, icons, shields, circles, phones, folders, bubbles, and symbolic marks are allowed only when they do not read as text.

## Visual Direction

- The reference image is for style only, not content cloning.
- Keep the feel: calm flat editorial illustration, soft blue/off-white palette, rounded shapes, subtle depth, gentle gradients.
- Make the thumbnails emotional and comforting. The user should feel protected, calmer, and less alone.
- Avoid alarmist, legalistic, or harsh visuals. Even legal/evidence topics should feel careful and reassuring.
- Do not reuse one identical woman character across all images.
- Vary characters and scenes:
  - gender presentation: women, men, and androgynous characters
  - age impression: young adult, parent, teacher, professional, student
  - pose: standing, sitting, walking away, writing, holding phone, resting, listening
  - distance: full body, half body, over-shoulder, small character in a larger symbolic scene
- Keep Korean cultural neutrality: modern everyday people, no celebrity likeness, no real platform logos.

## Prompt Template

Use this shape for each image:

```text
Use case: illustration-story
Asset type: text-free Infocutter blog thumbnail, landscape 4:3
Reference image: use the attached image only for visual style: calm flat editorial illustration, blue/off-white palette, soft rounded shapes, gentle Korean blog tone.
Primary request: Create an emotional character-centered thumbnail for the theme: <theme>.
Subject: <character variety + scene + symbolic props>.
Style: polished flat digital editorial illustration, soft blue/off-white background, subtle circular ripples, quiet depth, gentle gradients, emotionally safe and comforting.
Composition: horizontal 4:3, thumbnail-ready, character and symbolic scene fill the frame, no title area needed.
Text constraints: absolutely no visible letters, no Korean, no English, no numbers, no logo, no watermark, no readable UI text; all cards, bubbles, and screens must be blank or purely abstract.
Avoid: fear marketing, aggressive mobs, realistic self-harm imagery, sexual imagery, courtroom intimidation, real brand marks.
```

## Theme Mapping Guidance

- Psychology/recovery posts: use breathing space, muted phones, protective bubbles, soft light, blankets, tea, journaling, plants, paths, listening figures.
- Evidence/legal posts: use calm folders, shields, blank document cards, sealed boxes, clocks, abstract scales, careful hands.
- Deepfake/takedown posts: use abstract image fragments, protective layers, cleanup paths, monitoring lights, no realistic faces or sexualized content.
- Platform/reporting/product posts: use browser-like blank panels, personal safety layers, shields, hidden/muted bubbles, preserved evidence boxes.

## Thumbnail Examples

1. Rechecking hurtful comments: a young adult sits beside a softly glowing phone, with a gentle loop arrow and blank comment bubbles fading into a protective blue space.
2. Not looking as protection: an older adult turns a phone face down while a translucent shield and warm blanket of light block blank harmful bubbles.
3. Supporting a loved one: two people sit in a quiet living room with a muted phone on the table, one listening with open hands under warm light.
4. Evidence preservation: careful hands place blank screenshot cards into a glowing archive box with a shield and soft clock icon, no writing anywhere.
5. Personal safety layer: a calm person views a blank browser-like panel through a transparent protective layer while an evidence folder stays safely preserved.

## Validation

After generation:

- Copy generated files into `introduce/blog/images/` without deleting originals under `$CODEX_HOME/generated_images`.
- Ensure one PNG per numbered Markdown file.
- Normalize workspace copies to `1200x900` if the generator returns another 4:3 size.
- Inspect representative samples for no visible text, 4:3 landscape composition, character/style variety, and calm emotional tone.
