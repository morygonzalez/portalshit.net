// カラーモードの適用は原則 CSS が担当する。
//
//   - 明示指定あり … サーバーがクッキーを見て html に `dark-mode` /
//     `light-mode` クラスを出力する
//   - 明示指定なし … クラスを付けず、CSS の `prefers-color-scheme`
//     メディアクエリに任せる
//
// JS でクラスを付け外しすると初回描画に間に合わずチラつくため、ここでは
// テーマメニューの操作とクッキーの読み書きのみを扱う。
class ThemeObserver {
  constructor() {
    this.initColorMode();
    this.observeThemeMenu();
    this.observeThemeSelect();
  }

  getColorPreference()  {
    const allCookies = document.cookie.split('; ');
    const colorPreference = allCookies.find(item => item.startsWith('prefers-color-scheme'));
    let preference;

    if (colorPreference) {
      preference = colorPreference.split('=')[1];
    } else {
      preference = null;
    }

    return preference;
  }

  getServerDetectedColorMode()  {
    let mode;

    if (document.documentElement.classList.contains('dark-mode')) {
      mode = 'dark-mode';
    } else if (document.documentElement.classList.contains('light-mode')) {
      mode = 'light-mode';
    } else {
      mode = null;
    }

    return mode;
  }

  // 通常はサーバーがクッキーを見てクラスを出力済みなので何もしない。
  // ブラウザキャッシュから復元された HTML など、クッキーとクラスが食い違って
  // いる場合のみ補正する。明示指定がないときはクラスを付けない（CSS 側の
  // `prefers-color-scheme` に従わせる）。
  initColorMode()  {
    const colorPreference = this.getColorPreference();

    if (this.getServerDetectedColorMode() === colorPreference) {
      return;
    }

    this.applyColorMode(colorPreference);
  }

  applyColorMode(colorMode)  {
    document.documentElement.classList.remove('light-mode', 'dark-mode');

    if (colorMode) {
      document.documentElement.classList.add(colorMode);
    }
  }

  initThemeMenu()  {
    const button = document.querySelector('.theme button');
    const themeMenuModal = document.querySelector('.theme-menu');
    const colorPreference = this.getColorPreference();
    let selectedMode, selectedTheme, selectedThemeIcon;

    if (colorPreference) {
      selectedMode = colorPreference;
      selectedTheme = selectedMode === 'light-mode' ? 'Light' : 'Dark';
      selectedThemeIcon = selectedTheme === 'Light' ? 'sun' : 'moon';
      button.innerHTML = `<i class="far fa-${selectedThemeIcon}"></i><span>Theme</span>`;
    } else {
      selectedTheme = 'OS Default';
      selectedThemeIcon = 'adjust';
      button.innerHTML = '<i class="fas fa-adjust"></i><span>Theme</span>';
    }

    if (selectedTheme === 'Light') {
      themeMenuModal.querySelector('button.theme-light').parentNode.classList.add('selected');
    } else if (selectedTheme === 'Dark') {
      themeMenuModal.querySelector('button.theme-dark').parentNode.classList.add('selected');
    } else {
      themeMenuModal.querySelector('button.theme-default').parentNode.classList.add('selected');
    }
  }

  observeThemeMenu()  {
    const button = document.querySelector('.theme button');
    const themeMenuModal = document.querySelector('.theme-menu');

    this.initThemeMenu();

    if (button) {
      button.onclick = () => {
        document.querySelectorAll('.modal.active').forEach(modal => modal.classList.toggle('active'));
        themeMenuModal.classList.toggle('active')
      }
    }
  }

  observeThemeSelect()  {
    const buttons = document.querySelectorAll('.theme-button');
    const themeMenuModal = document.querySelector('.theme-menu');

    if (buttons.length > 0) {
      buttons.forEach(button => {
        button.onclick = () => {
          let newColorMode;

          if (button.classList.contains('theme-light')) {
            newColorMode = 'light-mode';
          } else if (button.classList.contains('theme-dark')) {
            newColorMode = 'dark-mode';
          } else {
            newColorMode = null;
          }

          this.changeTheme(newColorMode);
          themeMenuModal.classList.toggle('active');
          themeMenuModal.querySelectorAll('li').forEach(item => { item.classList.remove('selected') });
          this.initThemeMenu();
        }
      })
    }
  }

  changeTheme(newColorMode) {
    if (newColorMode) {
      document.cookie = `prefers-color-scheme=${newColorMode};max-age=604800;path=/`;
    } else {
      // OS 設定に従う。クラスを外すと CSS の `prefers-color-scheme` が効く。
      document.cookie = `prefers-color-scheme=;max-age=0;path=/`;
    }

    this.applyColorMode(newColorMode);
  }
}

export default ThemeObserver
