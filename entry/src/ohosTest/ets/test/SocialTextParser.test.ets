import { describe, expect, it } from '@ohos/hypium';
import { SocialTextContent, SocialTextEntityKind } from '../../../main/ets/model/WeiboModels';
import { SocialTextParser } from '../../../main/ets/service/SocialTextParser';

export default function socialTextParserTest() {
  describe('SocialTextParser', () => {
    it('finds_topics_and_mentions_in_plain_text', 0, () => {
      const content = SocialTextParser.parse('看 #鸿蒙#，关注 @开发者小明。');
      expect(content.entities.length).assertEqual(2);
      expect(content.entities[0].kind).assertEqual(SocialTextEntityKind.TOPIC);
      expect(content.entities[0].query).assertEqual('鸿蒙');
      expect(content.entities[1].kind).assertEqual(SocialTextEntityKind.MENTION);
      expect(content.entities[1].query).assertEqual('开发者小明');
    });

    it('keeps_uid_from_matching_html_anchor', 0, () => {
      const content = SocialTextParser.parse('你好 @Alice #HarmonyOS#',
        '你好 <a href="https://weibo.com/u/123456">@Alice</a> ' +
          '<a href="https://s.weibo.com/weibo?q=%23HarmonyOS%23">#HarmonyOS#</a>');
      expect(content.entities.length).assertEqual(2);
      expect(content.entities[0].userId).assertEqual('123456');
      expect(content.entities[1].query).assertEqual('HarmonyOS');
    });

    it('does_not_treat_email_or_incomplete_topic_as_entity', 0, () => {
      const content = SocialTextParser.parse('mail user@example.com and #unfinished');
      expect(content.entities.length).assertEqual(0);
    });

    it('parses_long_html_and_decodes_entities', 0, () => {
      const content = SocialTextParser.parse('',
        '第一行<br><a href="/n/Bob">@Bob</a> &amp; <a href="/topic">#测试#</a>');
      expect(content.text).assertEqual('第一行\n@Bob & #测试#');
      expect(content.entities.length).assertEqual(2);
      expect(content.entities[0].userId).assertEqual('');
    });

    it('keeps_http_link_from_html_anchor', 0, () => {
      const content = SocialTextParser.parse('查看 网页链接',
        '查看 <a href="HTTPS://example.com/article?id=1">网页链接</a>');
      expect(content.entities.length).assertEqual(1);
      expect(content.entities[0].kind).assertEqual(SocialTextEntityKind.LINK);
      expect(content.entities[0].displayText).assertEqual('网页链接');
      expect(content.entities[0].url).assertEqual('https://example.com/article?id=1');
    });

    it('unwraps_weibo_sinaurl_target', 0, () => {
      const content = SocialTextParser.parse('',
        '<a href="https://weibo.cn/sinaurl?u=https%3A%2F%2Fhuacheng.gz-cmc.com%2Farticle.html">网页链接</a>');
      expect(content.entities.length).assertEqual(1);
      expect(content.entities[0].kind).assertEqual(SocialTextEntityKind.LINK);
      expect(content.entities[0].url).assertEqual('https://huacheng.gz-cmc.com/article.html');
    });

    it('treats_weibo_super_topic_link_as_topic', 0, () => {
      const content: SocialTextContent = SocialTextParser.parse('',
        '<a href="https://m.weibo.cn/p/index?extparam=%E6%96%B0%E4%B8%96%E7%95%8C%E9%BB%91%E5%B8%82' +
          '&amp;containerid=1008082a6bcb8ecce206a8f44f675dcd05fe10">新世界黑市</a>');
      expect(content.entities.length).assertEqual(1);
      expect(content.entities[0].kind).assertEqual(SocialTextEntityKind.TOPIC);
      expect(content.entities[0].query).assertEqual('新世界黑市');
      expect(content.entities[0].url).assertEqual('');
    });

    it('uses_super_topic_label_when_extparam_is_invalid', 0, () => {
      const content: SocialTextContent = SocialTextParser.parse('',
        '<a href="/p/index?extparam=%E0%A4%A&amp;containerid=100808topic">#备用话题#</a>');
      expect(content.entities.length).assertEqual(1);
      expect(content.entities[0].kind).assertEqual(SocialTextEntityKind.TOPIC);
      expect(content.entities[0].query).assertEqual('备用话题');
    });

    it('ignores_unsafe_link_protocol', 0, () => {
      const content = SocialTextParser.parse('', '<a href="javascript:alert(1)">网页链接</a>');
      expect(content.text).assertEqual('网页链接');
      expect(content.entities.length).assertEqual(0);
    });

    it('orders_links_and_topics_by_display_position', 0, () => {
      const content = SocialTextParser.parse('#话题一# 网页链接 #话题二#',
        '<a href="/search?q=one">#话题一#</a> '
          + '<a href="https://example.com">网页链接</a> '
          + '<a href="/search?q=two">#话题二#</a>');
      expect(content.entities.length).assertEqual(3);
      expect(content.entities[0].kind).assertEqual(SocialTextEntityKind.TOPIC);
      expect(content.entities[1].kind).assertEqual(SocialTextEntityKind.LINK);
      expect(content.entities[2].kind).assertEqual(SocialTextEntityKind.TOPIC);
      expect(content.entities[1].start).assertEqual(6);
    });

    it('finds_plain_http_links_and_trims_sentence_punctuation', 0, () => {
      const content: SocialTextContent = SocialTextParser.parse(
        '官网 https://example.com/path?id=1，备用 HTTP://example.org/end。');
      expect(content.entities.length).assertEqual(2);
      expect(content.entities[0].kind).assertEqual(SocialTextEntityKind.LINK);
      expect(content.entities[0].url).assertEqual('https://example.com/path?id=1');
      expect(content.entities[1].url).assertEqual('http://example.org/end');
    });

    it('keeps_balanced_url_brackets_and_trims_unmatched_sentence_brackets', 0, () => {
      const content: SocialTextContent = SocialTextParser.parse(
        '词条 https://example.com/wiki/Function_(math)；参考（https://example.org/page）。');
      expect(content.entities.length).assertEqual(2);
      expect(content.entities[0].url).assertEqual('https://example.com/wiki/Function_(math)');
      expect(content.entities[1].url).assertEqual('https://example.org/page');
    });

    it('does_not_duplicate_plain_url_already_covered_by_anchor', 0, () => {
      const content: SocialTextContent = SocialTextParser.parse('访问 https://example.com/page',
        '访问 <a href="https://example.com/page">https://example.com/page</a>');
      expect(content.entities.length).assertEqual(1);
      expect(content.entities[0].url).assertEqual('https://example.com/page');
    });

    it('parses_all_entities_from_reported_post', 0, () => {
      const text: string = '#鹤屋现货# 未开封新品 【鹤屋现货】商品 胜利女神nikke';
      const html: string = '<a href="https://m.weibo.cn/search?q=topic">#鹤屋现货#</a> 未开封新品 ' +
        '<a href="http://apps.weibo.com/linkcard/item">【鹤屋现货】商品</a> ' +
        '<a href="https://m.weibo.cn/p/index?containerid=game">胜利女神nikke</a>';
      const content: SocialTextContent = SocialTextParser.parse(text, html);
      expect(content.entities.length).assertEqual(3);
      expect(content.entities[0].kind).assertEqual(SocialTextEntityKind.TOPIC);
      expect(content.entities[1].url).assertEqual('http://apps.weibo.com/linkcard/item');
      expect(content.entities[2].url).assertEqual('https://m.weibo.cn/p/index?containerid=game');
    });
  });
}
