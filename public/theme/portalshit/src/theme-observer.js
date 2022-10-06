class ThemeObserver {
  constructor() {
    this.initColorMode();
    this.observeThemeMenu();
    this.observeThemeSelect();
    this.observeOSThemeChange();
  }

  getCurrentColorMode()  {
    const colorPreference = this.getColorPreference();
    let mode;

    if (colorPreference) {
      mode = colorPreference;
    } else {
      mode = this.getOSDefaultColorMode();
    }

    return mode;
  }

  getOSDefaultColorMode()  {
    let mode;

    if (window.matchMedia('(prefers-color-scheme: light)').matches) {
      mode = 'light-mode';
    } else {
      mode = 'dark-mode';
    }

    return mode;
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

  initColorMode()  {
    const colorPreference = this.getColorPreference();
    const serverDetectedColorMode = this.getServerDetectedColorMode();

    if (serverDetectedColorMode) {
      // do nothing
    } else if (!serverDetectedColorMode && colorPreference) {
      document.documentElement.classList.add(colorPreference);
    } else if (!serverDetectedColorMode && !colorPreference) {
      const defaultMode = this.getOSDefaultColorMode();
      document.documentElement.classList.add(defaultMode);
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

  observeOSThemeChange() {
    window.matchMedia('(prefers-color-scheme: light)').addEventListener('change', (e)  => {
      const colorPreference = this.getColorPreference();

      if (colorPreference) {
        return;
      }

      let newColorMode;
      const colorModes = ['light-mode', 'dark-mode'];

      if (e.matches) {
        newColorMode = 'light-mode';
      } else {
        newColorMode = 'dark-mode';
      }

      const currentColorMode = colorModes.find(item => item != newColorMode);
      document.documentElement.classList.remove(currentColorMode);
      document.documentElement.classList.add(newColorMode);
    })
  }

  changeTheme(newColorMode) {
    const currentColorMode = this.getCurrentColorMode();
    document.documentElement.classList.remove(currentColorMode);

    if (newColorMode) {
      document.cookie = `prefers-color-scheme=${newColorMode};max-age=604800;path=/`;
      document.documentElement.classList.add(newColorMode);
    } else {
      document.cookie = `prefers-color-scheme=;max-age=0;path=/`;
      this.fallBackToDefaultTheme();
    }
  }

  fallBackToDefaultTheme()  {
    const newColorMode = this.getOSDefaultColorMode();
    document.documentElement.classList.add(newColorMode);
  }
}

export default ThemeObserver
