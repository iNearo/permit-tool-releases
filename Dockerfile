# Railway (أو أيّ Docker) يُشغّل نظامَ التصاريح كما يُثبّته العميل: من آخر إصدارٍ
# منشورٍ في iNearo/permit-tool-releases — حزمةِ لينكس الجاهزة — لا من الشفرة.
# فهذا الملفُّ وحده في مستودع الإصدارات العامّ، والشفرةُ تبقى في المستودع الخاصّ.
#
# ولا يُحدَّث وحده: زرُّ «تحديث الآن» في الإعدادات يطلب من Railway بناءً جديداً
# (بالمتغيّر RAILWAY_API_TOKEN — مفتاحُ المشروع)، فيجلب البناءُ آخرَ إصدار.
# ولتثبيت إصدارٍ بعينه: اضبط متغيّرَ البناء PERMIT_VERSION (مثل 1.1.0).
#
# البيانات: اربط Volume بالمسار /app/data، أو اضبط DATABASE_URL لقاعدة Postgres —
# وإلّا ضاعت التصاريحُ مع كلّ نشر.
FROM node:22-bookworm-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl \
      fonts-liberation fonts-noto-core fonts-kacst \
 && (apt-get install -y --no-install-recommends libreoffice-writer-nogui \
     || apt-get install -y --no-install-recommends libreoffice-writer) \
 && rm -rf /var/lib/apt/lists/*

# ‏ADD من رابطٍ يُبطل ذاكرةَ البناء متى تغيّر الإصدارُ الأخير — فلا يبقى القديمُ مخبوءاً
ADD https://api.github.com/repos/iNearo/permit-tool-releases/releases/latest /tmp/latest.json
ARG PERMIT_VERSION=""

WORKDIR /opt
# الحزمةُ تُنزَّل وتُطابَق ببصمتها المنشورة قبل أن تُفكّ — كما يفعل البرنامجُ عند العميل
RUN set -e; \
    V="${PERMIT_VERSION}"; \
    if [ -n "$V" ]; then \
      curl -fsSL "https://api.github.com/repos/iNearo/permit-tool-releases/releases/tags/v$V" -o /tmp/rel.json; \
    else cp /tmp/latest.json /tmp/rel.json; fi; \
    node -e ' \
      const r = JSON.parse(require("fs").readFileSync("/tmp/rel.json", "utf8")); \
      const a = (r.assets || []).find((x) => /^PermitTool-linux-.*\.tar\.gz$/.test(x.name)); \
      if (!a) { console.error("لا حزمةَ لينكس في الإصدار " + r.tag_name); process.exit(1); } \
      if (!/^sha256:[0-9a-f]{64}$/.test(a.digest || "")) { console.error("الحزمةُ بلا بصمةٍ منشورة"); process.exit(1); } \
      console.log(a.browser_download_url + " " + a.digest.slice(7) + " " + r.tag_name); \
    ' > /tmp/pick; \
    read URL SHA TAG < /tmp/pick; \
    echo "الإصدار: $TAG"; \
    curl -fsSL "$URL" -o /tmp/pkg.tgz; \
    echo "$SHA  /tmp/pkg.tgz" | sha256sum -c -; \
    tar -xzf /tmp/pkg.tgz -C /opt; \
    mv /opt/linux /opt/permit-tool; \
    rm -f /tmp/pkg.tgz /tmp/rel.json /tmp/latest.json

# خطٌّ عربيٌّ بمقاييس Arial، وقاعدةٌ تُلزم المحرّكَ به (إن حملتها الحزمة)
RUN mkdir -p /usr/local/share/fonts/permit /etc/fonts/conf.d /app/data \
 && cp /opt/permit-tool/app/deploy/fonts/*.ttf /usr/local/share/fonts/permit/ \
 && if [ -f /opt/permit-tool/app/deploy/fonts-arabic.conf ]; then \
      cp /opt/permit-tool/app/deploy/fonts-arabic.conf /etc/fonts/conf.d/99-permit-fonts.conf; fi \
 && fc-cache -f

ENV PORT=8080 CONFIG_DIR=/app/data SQLITE_FILE=/app/data/permits.db
EXPOSE 8080
CMD ["/opt/permit-tool/start.sh"]
