# FreeBSD Port: moltbot
# AI assistant gateway with messaging platform integrations

PORTNAME=	moltbot
DISTVERSION=	2026.1.24.3
CATEGORIES=	net-im
MASTER_SITES=	# npm package, no distfile

MAINTAINER=	dylan@rbpgroup.com
COMMENT=	Self-hosted AI assistant with Telegram/WhatsApp/Discord integrations
WWW=		https://github.com/moltbot/moltbot

LICENSE=	MIT
LICENSE_FILE=	${WRKSRC}/LICENSE

BUILD_DEPENDS=	npm:www/npm-node22 \
		rust>=1.70:lang/rust \
		${LOCALBASE}/include/vips/vips.h:graphics/vips
RUN_DEPENDS=	node:www/node22

USES=		python:3.11,build pkgconfig

NO_ARCH=	yes
NO_BUILD=	yes

do-extract:
	@${MKDIR} ${WRKSRC}

do-install:
	@${ECHO_MSG} "===> Installing moltbot via npm"
	@cd ${WRKSRC} && ${SETENV} HOME=${WRKDIR} npm install -g moltbot \
		--prefix=${STAGEDIR}${PREFIX}
	@${ECHO_MSG} "===> Building native modules for FreeBSD"
	@cd ${STAGEDIR}${PREFIX}/lib/node_modules/moltbot && \
		${SETENV} HOME=${WRKDIR} npm install node-addon-api node-gyp --save-dev
	@cd ${STAGEDIR}${PREFIX}/lib/node_modules/moltbot/node_modules/@mariozechner/clipboard && \
		${SETENV} HOME=${WRKDIR} npm install @napi-rs/cli && \
		${SETENV} HOME=${WRKDIR} npx napi build --platform --release
	@cd ${STAGEDIR}${PREFIX}/lib/node_modules/moltbot && \
		${SETENV} HOME=${WRKDIR} npm rebuild sharp
	@${ECHO_MSG} "===> Installing rc.d script"
	@${MKDIR} ${STAGEDIR}${PREFIX}/etc/rc.d
	@${INSTALL_SCRIPT} ${FILESDIR}/moltbot.in ${STAGEDIR}${PREFIX}/etc/rc.d/moltbot

post-install:
	@${STRIP_CMD} ${STAGEDIR}${PREFIX}/lib/node_modules/moltbot/node_modules/@mariozechner/clipboard/*.node 2>/dev/null || true

.include <bsd.port.mk>
