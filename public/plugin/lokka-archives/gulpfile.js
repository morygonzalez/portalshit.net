const gulp = require("gulp");
const babili = require("gulp-babili")

gulp.task("minify", () =>
  gulp.src("./build/script.js")
    .pipe(babili({
      mangle: {
        keepClassNames: true
      }
    }))
    .pipe(gulp.dest("./dist")));
