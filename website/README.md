# The Cassety website

Plain files for cassety.com. There is nothing to build or install: upload the contents of this folder to any web host and it works.

## What is here

| File | What it is |
| --- | --- |
| `index.html` | The home page |
| `support.html` | Help and contact. This is the Support URL for App Store Connect. |
| `privacy.html` | The privacy policy. This is the Privacy Policy URL for App Store Connect. |
| `404.html` | Shown for addresses that do not exist |
| `styles.css` | The look of every page |
| `images/` | The icon and the pictures of the app |
| `fonts/` | The display font, served from the site itself. It is free to use (SIL Open Font License); see `fonts/LICENSE.txt`. |
| `CNAME`, `robots.txt`, `sitemap.xml` | Housekeeping for the host and for search engines |

## The addresses to give Apple

* Privacy Policy URL: `https://cassety.com/privacy.html`
* Support URL: `https://cassety.com/support.html`
* Marketing URL: `https://cassety.com`

The app's Settings screen already links to the first two.

## Putting it online

Any of these will host it for free.

**GitHub Pages**, since the files are already in this repository: in the repository's Settings, open Pages, choose "GitHub Actions" or deploy from a branch, and point it at the `website` folder. Then enter `cassety.com` as the custom domain. The `CNAME` file here is for that.

**Netlify or Cloudflare Pages**: create a site, connect this repository, and set the folder to publish to `website`. There is no build command. Then add `cassety.com` as the custom domain.

In every case you then go to wherever you bought cassety.com and point the domain at the host, following the host's instructions. It can take up to a day to take effect. Make sure the site loads with `https`.

## Before you publish

1. **Email.** The pages give `support@cassety.com` as the contact. Set that address up with your domain, or change it in the three pages to one you already read. Apple requires a working way to reach you.
2. **The date** at the top of `privacy.html`. Set it to the day you publish.
3. **The pictures.** The `duo-*.webp` images are real screenshots of the app in Xcode's iPhone Duo simulator, showing a made-up demo tape (a debug build launched with `-demoTape`), because the simulator cannot play Apple Music. Retake them the same way after any change to the look, or replace them with screenshots from a phone.
4. **The App Store button.** The home page says "Coming soon to the App Store". When the app is live, replace that with Apple's official "Download on the App Store" badge from Apple's marketing resources, linked to the app's page.
