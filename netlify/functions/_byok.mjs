// The reader's own Gemini key is required — 2026-09-18.
//
// Until today the three AI functions tried the reader's key first and
// fell back to the developer's shared keys (GEMINI_API_KEY, its
// backups, GEMINI_API_KEYS) — on no key at all, and on any 4xx from the
// reader's key. The owner retired the shared key: 「dev gemini token可以
// 拿去了 如果他们要用 用的时候要提醒要绑定api 而且有清晰方法告诉他们」.
//
// So there is no fallback any more, and no shared key is read. A request
// without a well-formed reader key is answered with this error: HTTP
// 401, a machine code the app recognises (`byokRequired`), and a message
// in the reader's language that says what to do — because an app that
// predates the change shows the server's message verbatim, and that
// message is the only help those readers will get.
//
// The key the reader pastes stays theirs: it arrives in the request body,
// is used for this one call, and is never logged or stored.

const MESSAGES = {
	'zh-Hans':
		'AI 功能需要你自己的 Gemini API 密钥（免费）。' +
		'获取方法：打开 aistudio.google.com/apikey，用 Google 账号登录，' +
		'点「Create API key」，复制以 AIza 开头的密钥；' +
		'然后在 app 的「设置」›「AI 释义」›「使用我自己的 Gemini API 密钥」里粘贴并测试。',
	'zh-Hant':
		'AI 功能需要你自己的 Gemini API 金鑰（免費）。' +
		'取得方法：打開 aistudio.google.com/apikey，用 Google 帳號登入，' +
		'點「Create API key」，複製以 AIza 開頭的金鑰；' +
		'然後在 app 的「設定」›「AI 釋義」›「使用我自己的 Gemini API 金鑰」裡貼上並測試。',
	en:
		'AI features need your own Gemini API key (free). ' +
		'To get one: open aistudio.google.com/apikey, sign in with a Google ' +
		'account, click "Create API key" and copy the key that starts with AIza; ' +
		'then paste it in the app under Settings › AI › "Use my own Gemini API ' +
		'key" and tap Test.',
};

export function byokRequiredError(locale) {
	const message = MESSAGES[locale] || MESSAGES.en;
	const err = new Error(message);
	err.publicReason = message;
	err.statusCode = 401;
	err.code = 'byokRequired';
	return err;
}
