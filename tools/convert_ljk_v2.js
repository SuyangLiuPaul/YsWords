#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

const rootDir = path.resolve(__dirname, '..');
const resourcesDir = path.join(
  rootDir,
  'ljk-nt-bible-webapp',
  'public',
  'resources',
);
const assetsDir = path.join(rootDir, 'assets');

const books = [
  ['mt', 'Matthew', 40],
  ['mk', 'Mark', 41],
  ['lk', 'Luke', 42],
  ['joh', 'John', 43],
  ['act', 'Acts', 44],
  ['rom', 'Romans', 45],
  ['1co', '1 Corinthians', 46],
  ['2co', '2 Corinthians', 47],
  ['gal', 'Galatians', 48],
  ['eph', 'Ephesians', 49],
  ['phi', 'Philippians', 50],
  ['col', 'Colossians', 51],
  ['1th', '1 Thessalonians', 52],
  ['2th', '2 Thessalonians', 53],
  ['1ti', '1 Timothy', 54],
  ['2ti', '2 Timothy', 55],
  ['tit', 'Titus', 56],
  ['phm', 'Philemon', 57],
  ['heb', 'Hebrews', 58],
  ['jas', 'James', 59],
  ['1pe', '1 Peter', 60],
  ['2pe', '2 Peter', 61],
  ['1jo', '1 John', 62],
  ['2jo', '2 John', 63],
  ['3jo', '3 John', 64],
  ['jud', 'Jude', 65],
  ['rev', 'Revelation', 66],
];

const localizedNames = {
  cn: {
    Matthew: '马太福音',
    Mark: '马可福音',
    Luke: '路加福音',
    John: '约翰福音',
    Acts: '使徒行传',
    Romans: '罗马书',
    '1 Corinthians': '哥林多前书',
    '2 Corinthians': '哥林多后书',
    Galatians: '加拉太书',
    Ephesians: '以弗所书',
    Philippians: '腓立比书',
    Colossians: '歌罗西书',
    '1 Thessalonians': '帖撒罗尼迦前书',
    '2 Thessalonians': '帖撒罗尼迦后书',
    '1 Timothy': '提摩太前书',
    '2 Timothy': '提摩太后书',
    Titus: '提多书',
    Philemon: '腓利门书',
    Hebrews: '希伯来书',
    James: '雅各书',
    '1 Peter': '彼得前书',
    '2 Peter': '彼得后书',
    '1 John': '约翰一书',
    '2 John': '约翰二书',
    '3 John': '约翰三书',
    Jude: '犹大书',
    Revelation: '启示录',
  },
  tw: {
    Matthew: '馬太福音',
    Mark: '馬可福音',
    Luke: '路加福音',
    John: '約翰福音',
    Acts: '使徒行傳',
    Romans: '羅馬書',
    '1 Corinthians': '哥林多前書',
    '2 Corinthians': '哥林多後書',
    Galatians: '加拉太書',
    Ephesians: '以弗所書',
    Philippians: '腓立比書',
    Colossians: '歌羅西書',
    '1 Thessalonians': '帖撒羅尼迦前書',
    '2 Thessalonians': '帖撒羅尼迦後書',
    '1 Timothy': '提摩太前書',
    '2 Timothy': '提摩太後書',
    Titus: '提多書',
    Philemon: '腓利門書',
    Hebrews: '希伯來書',
    James: '雅各書',
    '1 Peter': '彼得前書',
    '2 Peter': '彼得後書',
    '1 John': '約翰一書',
    '2 John': '約翰二書',
    '3 John': '約翰三書',
    Jude: '猶大書',
    Revelation: '啟示錄',
  },
};

function decodeEntities(value) {
  return value
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'");
}

function normalizeText(value) {
  return decodeEntities(value)
    .replace(/\s+/g, ' ')
    .replace(/\s+([，。！？；：、,.!?;:])/g, '$1')
    .trim();
}

function convertHtmlContent(value, notes) {
  let text = value;

  text = text.replace(/<cite[^>]*>(.*?)<\/cite>/gis, (_, note) => {
    const clean = normalizeText(note.replace(/<[^>]+>/g, ''));
    if (clean) notes.push(clean);
    return '';
  });

  text = text.replace(/<br\s*\/?>/gi, ' ');
  text = text.replace(/<[^>]+>/g, '');

  return normalizeText(text);
}

function parseVerseIndex(rawIndex) {
  const label = String(rawIndex || '').trim();
  const match = label.match(/\d+/);
  if (!match) return null;

  return {
    verse: Number.parseInt(match[0], 10),
    label,
  };
}

function makeId(bookNumber, chapter, verse, label) {
  const compactLabel = label.includes('-')
    ? label.replace(/[^0-9]/g, '')
    : String(verse).padStart(3, '0');
  return `${String(bookNumber).padStart(2, '0')}${String(chapter).padStart(3, '0')}${compactLabel}`;
}

function convertLanguage(lang, outputName) {
  const output = [];
  const warnings = [];

  for (const [abbr, englishName, bookNumber] of books) {
    const filePath = path.join(resourcesDir, `${lang}-${abbr}.json`);
    const chapters = JSON.parse(fs.readFileSync(filePath, 'utf8'));
    const book = localizedNames[lang][englishName];

    chapters.forEach((chapterData, chapterIndex) => {
      const chapter = chapterIndex + 1;
      const nodes = Array.isArray(chapterData.nodeData)
        ? chapterData.nodeData
        : [];

      for (const node of nodes) {
        if (node.type !== 'verse') continue;

        const parsed = parseVerseIndex(node.verseIndex);
        if (!parsed) {
          warnings.push(`${lang}-${abbr} ${chapter}:${node.verseIndex || '(blank)'}`);
          continue;
        }

        const notes = [];
        const textParts = [];

        for (const part of node.contents || []) {
          const converted = convertHtmlContent(String(part.content || ''), notes);
          if (converted) textParts.push(converted);
        }

        const noteSuffix = notes.map(note => `<note:${note}>`).join('');
        const text = `${textParts.join(' ')}${noteSuffix}`.trim();
        if (!text) continue;

        output.push({
          book,
          chapter: String(chapter),
          verse: String(parsed.verse),
          verseLabel: parsed.label,
          text,
          isParagraphStart:
            node.paragraph === 'paragraph' || node.paragraph === 'reference',
          paragraphType: node.paragraph || 'inline',
          id: makeId(bookNumber, chapter, parsed.verse, parsed.label),
        });
      }
    });
  }

  const outputPath = path.join(assetsDir, outputName);
  fs.writeFileSync(outputPath, `${JSON.stringify(output, null, 2)}\n`);

  console.log(`${outputName}: ${output.length} verses`);
  if (warnings.length) {
    console.log(`Skipped ${warnings.length} malformed verse labels:`);
    warnings.forEach(item => console.log(`  - ${item}`));
  }
}

if (!fs.existsSync(resourcesDir)) {
  console.error(`Missing resources directory: ${resourcesDir}`);
  process.exit(1);
}

convertLanguage('cn', 'biblexg-v2.json');
convertLanguage('tw', 'biblexg-v2-tr.json');
