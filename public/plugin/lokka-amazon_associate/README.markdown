# Amazon Product Advertising API client for Lokka

## What is this?

This is the plugin which enables your lokka to access to Amazon Product Advertising API.

## How to use?

Download this scripts under `LOKKA_ROOT/public/plugin/` then access to `http://yourhostname/admin/plugins/amazon_associate` via web browser. Input your Associate Tag, Access Key ID and Secret Key.

Next, edit your lokka theme as follows. For instance, if your theme's `entry.haml` is marked up as below;

```haml
.body
  = entry.body
```

then you should wrap `entry.body` object with `associate_link()` method just like below.

```haml
.body
  = associate_link entry.haml
```

`associate_link` is the helper method which detects ASIN/ISBN tag and replace it to Amazon associated link.

Finaly, write blog entry and insert ASIN/ISBN code with the format like `<!-- ASIN=PRODUCTID -->` to where you want associated link to appear.
