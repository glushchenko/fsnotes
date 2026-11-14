var ExtensionPreprocessingJS = {
    run: function (arguments) {
        const noise = [
            'nav', 'aside', 'footer', 'form', 'button', 'input', 'select', 'textarea', 'dialog',
            'script', 'style', 'noscript', 'template', 'svg', 'iframe', 'canvas',
            '[hidden]', '[inert]', '[role="navigation"]',
            '[role="banner"]', '[role="complementary"]', '[role="contentinfo"]',
            '[role="dialog"]', '[role="menu"]', '[role="toolbar"]', '[role="search"]',
            '.breadcrumb', '.breadcrumbs', '.cookie-banner', '.share-buttons', '.social-links'
        ].join(',');
        const main = document.querySelector('main, [role="main"]') || document.body;
        const articles = main ? Array.from(main.querySelectorAll('article, [itemprop="articleBody"]')) : [];
        // Prefer an article with substantial prose over a card in a list of links.
        const scored = articles.map(article => ({
            article,
            length: Array.from(article.querySelectorAll('p, pre, blockquote'))
                .reduce((length, paragraph) => length + paragraph.textContent.trim().length, 0)
        })).sort((a, b) => b.length - a.length);
        const content = scored.length && scored[0].length >= 120 ? scored[0].article : main;

        function copyVisible(node) {
            if (node.nodeType === Node.TEXT_NODE) {
                return node.cloneNode();
            }
            if (node.nodeType !== Node.ELEMENT_NODE || node.matches(noise)
                || (node.tagName === 'HEADER' && content === document.body && !node.closest('article'))) {
                return null;
            }
            const style = getComputedStyle(node);
            if (style.display === 'none' || style.visibility === 'hidden' || style.visibility === 'collapse') {
                return null;
            }

            const copy = node.cloneNode(false);
            if (node.tagName === 'IMG') {
                const bounds = node.getBoundingClientRect();
                const src = node.currentSrc || node.getAttribute('src');
                if (!src || bounds.width <= 1 || bounds.height <= 1
                    || (bounds.width <= 16 && bounds.height <= 16)
                    || (node.complete && (node.naturalWidth <= 1 || node.naturalHeight <= 1))) {
                    return null;
                }
                copy.setAttribute('src', src);
            }
            for (const child of node.childNodes) {
                const cleaned = copyVisible(child);
                if (cleaned) copy.appendChild(cleaned);
            }
            return copy;
        }

        const cleaned = content && copyVisible(content);
        arguments.completionFunction({
            title: document.title,
            url: document.URL,
            baseURL: document.baseURI,
            html: cleaned ? cleaned.outerHTML : ''
        });
    }
};
