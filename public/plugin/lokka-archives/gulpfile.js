const gulp = require("gulp");
const minify = require("gulp-babel-minify")

gulp.task("minify", () =>
  gulp.src("./build/script.js")
    .pipe(minify({
      mangle: {
        keepClassNames: true
      }
    }))
    .pipe(gulp.dest("./dist")));
