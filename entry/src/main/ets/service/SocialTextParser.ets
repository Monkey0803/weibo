import {
  SocialTextContent,
  SocialTextEntity,
  SocialTextEntityKind
} from '../model/WeiboModels';

export class SocialTextParser {
  static parse(rawText: string, htmlText: string = ''): SocialTextContent {
    const displayText: string = SocialTextParser.clean(rawText.length > 0 ? rawText : htmlText);
    const entities: SocialTextEntity[] = [];
    if (displayText.length === 0) {
      return new SocialTextContent();
    }
    if (htmlText.length > 0) {
      SocialTextParser.collectAnchors(displayText, htmlText, entities);
    }
    SocialTextParser.collectPlainLinks(displayText, entities);
    SocialTextParser.collectTopics(displayText, entities);
    SocialTextParser.collectMentions(displayText, entities);
    entities.sort((left: SocialTextEntity, right: SocialTextEntity): number => left.start - right.start);
    return new SocialTextContent(displayText, entities);
  }

  static clean(value: string): string {
    return SocialTextParser.decodeEntities(value
      .replace(/<br\s*\/?>/gi, '\n')
      .replace(/<[^>]+>/g, ''))
      .trim();
  }

  private static decodeEntities(value: string): string {
    return value
      .replace(/&nbsp;/gi, ' ')
      .replace(/&amp;/gi, '&')
      .replace(/&lt;/gi, '<')
      .replace(/&gt;/gi, '>')
      .replace(/&quot;/gi, '"')
      .replace(/&apos;/gi, "'")
      .replace(/&#39;/gi, "'");
  }

  private static collectAnchors(displayText: string, htmlText: string, entities: SocialTextEntity[]): void {
    const anchorPattern: RegExp = /<a\b[^>]*href\s*=\s*(?:"([^"]*)"|'([^']*)')[^>]*>([\s\S]*?)<\/a>/gi;
    let match: RegExpExecArray | null = anchorPattern.exec(htmlText);
    let searchOffset: number = 0;
    while (match !== null) {
      const href: string = SocialTextParser.decodeEntities(match[1] ?? match[2] ?? '');
      const label: string = SocialTextParser.clean(match[3] ?? '');
      let kind: SocialTextEntityKind | undefined = SocialTextParser.kindForLabel(label);
      let query: string = '';
      let url: string = '';
      if (kind === undefined) {
        query = SocialTextParser.superTopicQueryFromHref(href, label);
        if (query.length > 0) {
          kind = SocialTextEntityKind.TOPIC;
        } else {
          url = SocialTextParser.linkUrlFromHref(href);
        }
        if (kind === undefined && url.length > 0) {
          kind = SocialTextEntityKind.LINK;
        }
      }
      if (kind !== undefined) {
        let start: number = displayText.indexOf(label, searchOffset);
        if (start < 0) {
          start = displayText.indexOf(label);
        }
        if (start >= 0) {
          if (query.length === 0 && kind !== SocialTextEntityKind.LINK) {
            query = SocialTextParser.queryForLabel(label, kind);
          }
          const userId: string = kind === SocialTextEntityKind.MENTION ?
            SocialTextParser.userIdFromHref(href) : '';
          SocialTextParser.addEntity(entities,
            new SocialTextEntity(kind, start, label.length, label, query, userId, url));
          searchOffset = start + label.length;
        }
      }
      match = anchorPattern.exec(htmlText);
    }
  }

  private static kindForLabel(label: string): SocialTextEntityKind | undefined {
    if (label.length >= 3 && label.startsWith('#') && label.endsWith('#')) {
      return SocialTextEntityKind.TOPIC;
    }
    if (label.length >= 2 && label.startsWith('@')) {
      return SocialTextEntityKind.MENTION;
    }
    return undefined;
  }

  private static queryForLabel(label: string, kind: SocialTextEntityKind): string {
    if (kind === SocialTextEntityKind.TOPIC) {
      return label.substring(1, label.length - 1).trim();
    }
    return label.substring(1).trim();
  }

  private static superTopicQueryFromHref(href: string, label: string): string {
    const url: string = SocialTextParser.absoluteWeiboUrl(href);
    if (!/^https?:\/\/(?:m\.)?weibo\.cn\/p\/index\?/i.test(url)) {
      return '';
    }
    const containerMatch: RegExpMatchArray | null = url.match(/[?&]containerid=(100808[^&]*)/i);
    if (containerMatch === null) {
      return '';
    }
    const extParamMatch: RegExpMatchArray | null = url.match(/[?&]extparam=([^&]*)/i);
    if (extParamMatch !== null && extParamMatch.length > 1) {
      try {
        const query: string = decodeURIComponent(extParamMatch[1].replace(/\+/g, '%20')).trim();
        if (query.length > 0) {
          return SocialTextParser.trimTopicMarkers(query);
        }
      } catch (_error) {
        return SocialTextParser.trimTopicMarkers(label);
      }
    }
    return SocialTextParser.trimTopicMarkers(label);
  }

  private static absoluteWeiboUrl(href: string): string {
    const trimmed: string = href.trim();
    if (trimmed.startsWith('//')) {
      return 'https:' + trimmed;
    }
    if (trimmed.startsWith('/')) {
      return 'https://m.weibo.cn' + trimmed;
    }
    return trimmed;
  }

  private static trimTopicMarkers(value: string): string {
    const trimmed: string = value.trim();
    if (trimmed.length >= 3 && trimmed.startsWith('#') && trimmed.endsWith('#')) {
      return trimmed.substring(1, trimmed.length - 1).trim();
    }
    return trimmed;
  }

  private static userIdFromHref(href: string): string {
    const patterns: RegExp[] = [
      /(?:[?&](?:uid|value)=)(\d+)/i,
      /\/(?:u|profile)\/(\d+)/i,
      /weibo\.com\/(\d{5,})(?:\b|\/|\?)/i
    ];
    for (let index: number = 0; index < patterns.length; index++) {
      const match: RegExpMatchArray | null = href.match(patterns[index]);
      if (match !== null && match.length > 1) {
        return match[1];
      }
    }
    return '';
  }

  private static linkUrlFromHref(href: string): string {
    let url: string = href.trim();
    if (url.startsWith('//')) {
      url = 'https:' + url;
    } else if (url.startsWith('/')) {
      url = 'https://m.weibo.cn' + url;
    }
    url = SocialTextParser.normalizeHttpUrl(url);
    if (url.length === 0) {
      return '';
    }
    const sinaUrlPattern: RegExp = /^https?:\/\/(?:[^/]+\.)?weibo\.cn\/sinaurl\?/i;
    if (!sinaUrlPattern.test(url)) {
      return url;
    }
    const targetMatch: RegExpMatchArray | null = url.match(/[?&]u=([^&]*)/i);
    if (targetMatch === null || targetMatch.length < 2) {
      return url;
    }
    try {
      const target: string = SocialTextParser.normalizeHttpUrl(
        decodeURIComponent(targetMatch[1].replace(/\+/g, '%20')));
      return target.length > 0 ? target : url;
    } catch (_err) {
      return url;
    }
  }

  private static normalizeHttpUrl(value: string): string {
    const schemeMatch: RegExpMatchArray | null = value.match(/^https?:\/\//i);
    if (schemeMatch === null || !/^https?:\/\/[^\s]+$/i.test(value)) {
      return '';
    }
    return schemeMatch[0].toLowerCase() + value.substring(schemeMatch[0].length);
  }

  private static collectPlainLinks(text: string, entities: SocialTextEntity[]): void {
    const linkPattern: RegExp = new RegExp('https?:\\/\\/[^\\s，。！？；：]+', 'gi');
    let match: RegExpExecArray | null = linkPattern.exec(text);
    while (match !== null) {
      const display: string = SocialTextParser.trimLinkPunctuation(match[0]);
      const url: string = SocialTextParser.normalizeHttpUrl(display);
      if (url.length > 0) {
        SocialTextParser.addEntity(entities, new SocialTextEntity(SocialTextEntityKind.LINK,
          match.index, display.length, display, '', '', url));
      }
      match = linkPattern.exec(text);
    }
  }

  private static trimLinkPunctuation(value: string): string {
    const punctuation: string = '.,!?;:，。！？；：\"\'…';
    let end: number = value.length;
    while (end > 0) {
      const last: string = value[end - 1];
      if (punctuation.indexOf(last) >= 0 || SocialTextParser.hasUnmatchedClosing(value, end, last)) {
        end--;
      } else {
        break;
      }
    }
    return value.substring(0, end);
  }

  private static hasUnmatchedClosing(value: string, end: number, closing: string): boolean {
    let opening: string = '';
    if (closing === ')') {
      opening = '(';
    } else if (closing === ']') {
      opening = '[';
    } else if (closing === '}') {
      opening = '{';
    } else if (closing === '）') {
      opening = '（';
    } else if (closing === '】') {
      opening = '【';
    } else if (closing === '》') {
      opening = '《';
    } else {
      return false;
    }
    return SocialTextParser.countCharacter(value, end, closing) >
      SocialTextParser.countCharacter(value, end, opening);
  }

  private static countCharacter(value: string, end: number, character: string): number {
    let count: number = 0;
    for (let index: number = 0; index < end; index++) {
      if (value[index] === character) {
        count++;
      }
    }
    return count;
  }

  private static collectTopics(text: string, entities: SocialTextEntity[]): void {
    let opening: number = text.indexOf('#');
    while (opening >= 0) {
      const closing: number = text.indexOf('#', opening + 1);
      if (closing < 0) {
        return;
      }
      const content: string = text.substring(opening + 1, closing);
      if (content.length > 0 && content.length <= 100 && content.indexOf('\n') < 0 && content.trim().length > 0) {
        const display: string = text.substring(opening, closing + 1);
        SocialTextParser.addEntity(entities, new SocialTextEntity(SocialTextEntityKind.TOPIC,
          opening, display.length, display, content.trim()));
      }
      opening = text.indexOf('#', closing + 1);
    }
  }

  private static collectMentions(text: string, entities: SocialTextEntity[]): void {
    let start: number = text.indexOf('@');
    while (start >= 0) {
      let end: number = start + 1;
      while (end < text.length && !SocialTextParser.isMentionTerminator(text[end])) {
        end++;
      }
      if (end > start + 1 && SocialTextParser.isMentionBoundary(text, start)) {
        const display: string = text.substring(start, end);
        SocialTextParser.addEntity(entities, new SocialTextEntity(SocialTextEntityKind.MENTION,
          start, display.length, display, display.substring(1).trim()));
      }
      start = text.indexOf('@', Math.max(end, start + 1));
    }
  }

  private static isMentionBoundary(text: string, start: number): boolean {
    if (start === 0) {
      return true;
    }
    const previous: string = text[start - 1];
    return !/[A-Za-z0-9._%+-]/.test(previous);
  }

  private static isMentionTerminator(character: string): boolean {
    return character.trim().length === 0 ||
      ',，。！？!?:：;；、()（）[]【】<>《》"“”\'‘’/\\#@'.indexOf(character) >= 0;
  }

  private static addEntity(entities: SocialTextEntity[], candidate: SocialTextEntity): void {
    const hasTarget: boolean = candidate.kind === SocialTextEntityKind.LINK ?
      candidate.url.length > 0 : candidate.query.length > 0;
    if (!hasTarget || candidate.start < 0 || candidate.length <= 0) {
      return;
    }
    const candidateEnd: number = candidate.start + candidate.length;
    for (let index: number = 0; index < entities.length; index++) {
      const existing: SocialTextEntity = entities[index];
      const existingEnd: number = existing.start + existing.length;
      if (candidate.start < existingEnd && candidateEnd > existing.start) {
        return;
      }
    }
    entities.push(candidate);
  }
}
