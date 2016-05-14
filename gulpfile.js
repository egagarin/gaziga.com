'use strict';

var gulp = require('gulp');
// Loads the plugins without having to list all of them, but you need
// to call them as $.pluginname
var $ = require('gulp-load-plugins')();
// 'del' is used to clean out directories and such
var del = require('del');
// 'fs' is used to read files from the system (used for AWS uploading)
var fs = require('fs');
// Parallelize the uploads when uploading to Amazon S3
var parallelize = require("concurrent-transform");
// BrowserSync isn't a gulp package, and needs to be loaded manually
var browserSync = require('browser-sync');
// merge is used to merge the output from two different streams into the same stream
var merge = require('merge-stream');
// Need a command for reloading webpages using BrowserSync
var reload = browserSync.reload;
var cp = require('child_process');
var minimist = require('minimist');
var cloudfront = require('cloudfront');
var glob = require("glob");
var _ = require('lodash');
var shell = require('gulp-shell');
var Promise = require("bluebird");
var rp = require('request-promise');
// And define a variable that BrowserSync uses in it's function
var bs;

var knownOptions = {
  string: 'post'
};

var options = minimist(process.argv.slice(2), knownOptions);


// Deletes the directory that is used to serve the site during development
gulp.task('clean:dev', del.bind(null, ['serve']));

// Deletes the directory that the optimized site is output to
gulp.task('clean:prod', del.bind(null, ['site']));

var messages = {
    jekyllBuild: '<span style="color: grey">Running</span> $ jekyll build'
};

// Runs the build command for Jekyll to compile the site locally
// This will build the site with the production settings
gulp.task('jekyll:dev', function (done) {
  browserSync.notify(messages.jekyllBuild);
  return cp.spawn('bundle', ['exec', 'jekyll', 'build', '--drafts'], {stdio: 'inherit'})
    .on('close', done);
});

// Almost identical to the above task, but instead we load in the build configuration
// that overwrites some of the settings in the regular configuration so that you
// don't end up publishing your drafts or future posts
gulp.task('jekyll:prod', $.shell.task('bundle exec jekyll build --config _config.yml,_config.prod.yml'));

// Compiles the SASS files and moves them into the 'assets/stylesheets' directory
gulp.task('styles', function () {
    // Looks at the style.scss file for what to include and creates a style.css file
//    console.log(require('node-neat').includePaths.map(function(el){
//  return el + "/*.scss";
//}));
    return $.rubySass('src/assets/scss/style.scss', { style: 'expanded', loadPath: require('node-neat').includePaths })

        //.pipe($.rubySass({
        //  //loadPath: require('node-neat').includePaths.map(function(el){
        //  //  return el + "/*.scss";
        //  //}), trace: true
        //}))
        // AutoPrefix your CSS so it works between browsers
        .pipe($.autoprefixer('last 1 version', { cascade: true }))
        // Directory your CSS file goes to
        .pipe(gulp.dest('src/assets/stylesheets/'))
        .pipe(gulp.dest('serve/assets/stylesheets/'))
        // Outputs the size of the CSS file
        .pipe($.size({title: 'SCSS'}))
        // Injects the CSS changes to your browser since Jekyll doesn't rebuild the CSS
        .pipe(reload({stream: true}));
});

// Optimizes the images that exists
gulp.task('images', function () {
    return gulp.src('src/assets/images/**/*')
        .pipe($.cache($.imagemin({
            // Runs 16 trials on the PNGs to better the optimization
            // Can by anything from 1 to 7, for more see
            // https://github.com/sindresorhus/gulp-imagemin#optimizationlevel-png
            optimizationLevel: 4,
            // Lossless conversion to progressive JPGs
            progressive: true,
            // Interlace GIFs for progressive rendering
            interlaced: true
        })))
        .pipe($.size({title: 'Images'}));
});

gulp.on('err', function(e) {
  console.log(e.err.stack);
});

// Optimizes all the CSS, HTML and concats the JS etc
gulp.task('html', ['styles'], function () {
    var assets = $.useref.assets({searchPath: 'serve'});
    return gulp.src('serve/**/*.html')
        .pipe($.plumber())
        .pipe(assets)
        .pipe($.if('*.css', $.minifyCss()))
        .pipe(assets.restore())
        .pipe($.useref())
        .pipe($.if('*.html', $.htmlmin({
            removeComments: true,
            removeCommentsFromCDATA: true,
            removeCDATASectionsFromCDATA: true,
            collapseWhitespace: true,
            collapseBooleanAttributes: true,
            removeAttributeQuotes: true,
            removeRedundantAttributes: true
        })))
        // Gzip your text files
        //.pipe($.if('*.html', $.gzip({append: false})))
        //.pipe($.if('*.xml', $.gzip({append: false})))
        //.pipe($.if('*.txt', $.gzip({append: false})))
        //.pipe($.if('*.css', $.gzip({append: false})))
        //.pipe($.if('*.js', $.gzip({append: false})))
        // Send the output to the correct folder
        .pipe(gulp.dest('site'))
        .pipe($.size({title: 'Optimizations'}));
});

// Task to deploy your site to Amazon S3 and Cloudfront
// Task to deploy your site to Amazon S3 and Cloudfront
gulp.task('deploy', function () {
  // Generate the needed credentials (bucket, secret key etc) from a "hidden" JSON file
  var credentials = {
    "key": process.env.AWS_S3_KEY,
    "secret": process.env.AWS_S3_SECRET,
    "bucket": "new.gaziga.com"
    //"region": "us-west-1",
    //"distributionId": "E1P667PTE7ROTP"
  };

  var publisher = $.awspublish.create(credentials);

  var headers = {
    'Cache-Control': 'max-age=315360000, no-transform, public'
    //'Content-Encoding': 'gzip'
  };
  gulp.src('site/**/*')
    .pipe($.plumber())
    //.pipe($.if('*.html', $.awspublish.gzip({ ext: '.gz' })))
    //.pipe($.if('*.xml', $.awspublish.gzip({ ext: '.gz' })))
    //.pipe($.if('*.txt', $.awspublish.gzip({ ext: '.gz' })))
    //.pipe($.if('*.css', $.awspublish.gzip({ ext: '.gz' })))
    //.pipe($.if('*.js', $.awspublish.gzip({ ext: '.gz' })))

    // Parallelize the number of concurrent uploads, in this case 30
    .pipe(parallelize(publisher.publish(headers), 30))
      //parallelize(publisher.publish(_.extend({'X-Robots-Tag': 'noindex'}, headers)), 30),)
    //.pipe(parallelize(publisher.publish(headers), 30))
    // Have your files in the system cache so you don't have to recheck all the files every time
    .pipe(publisher.cache())
    // Synchronize the contents of the bucket and local (this deletes everything that isn't in local!)
    //.pipe(publisher.sync()) //leave cached references
    // And print the ouput, glorious
    .pipe($.awspublish.reporter());
});

// Run JS Lint against your JS
gulp.task('jslint', function () {
  gulp.src('./serve/assets/javascript/*.js')
    // Checks your JS code quality against your .jshintrc file
    .pipe($.jshint('.jshintrc'))
    .pipe($.jshint.reporter());
});

// Runs 'jekyll doctor' on your site to check for errors with your configuration
// and will check for URL errors a well
gulp.task('doctor', $.shell.task('jekyll doctor'));

// Copies over images and .xml/.txt files to the distribution folder
gulp.task('copy', function () {
  var xmlandtxt = gulp.src(['serve/*.txt', 'serve/**/*.xml'])
    .pipe(gulp.dest('site'));
  var images = gulp.src('src/assets/images/**/*')
    .pipe(gulp.dest('site/assets/images'));
  var fonts = gulp.src(['src/assets/fonts/**/*', '!src/assets/fonts/config.json'])
    .pipe(gulp.dest('site/assets/fonts'));

  return merge(xmlandtxt, images, fonts);
});

// BrowserSync will serve our site on a local server for us and other devices to use
// It will also autoreload across all devices as well as keep the viewport synchronized
// between them.
gulp.task('serve:dev', function () {
    bs = browserSync({
        notify: true,
        // tunnel: '',
        server: {
          baseDir: ['serve', 'static']
        }
    });

    // These tasks will look for files that change while serving and will auto-regenerate or
    // reload the website accordingly. Update or add other files you need to be watched.
    //gulp.watch(['src/**/*.md', 'src/**/*.html'], ['jekyll:dev']);
    //gulp.watch(['serve/**/*.html', 'serve/**/*.css', 'serve/**/*.js'], reload);
    gulp.watch(['serve/**/*.css', 'serve/**/*.js'], reload);
    gulp.watch(['src/assets/scss/**/*.scss'], ['styles']);
});

// Serve the site after optimizations to see that everything looks fine
gulp.task('serve:prod', function () {
    bs = browserSync({
        notify: false,
        server: {
          baseDir: ['site', 'static']
        }
    });
});

// Default task, run when just writing 'gulp' in the terminal
gulp.task('default', ['build'], function () {
    gulp.start('serve:dev');
});

gulp.task('dev', ['build:dev'], function () {
  gulp.start('serve:dev');
});

// Checks your CSS, JS and Jekyll for errors
gulp.task('check', ['jslint', 'doctor'], function () {
  // Better hope nothing is wrong.
});

// Builds the site but doesn't serve it to you
gulp.task('build', ['jekyll:prod', 'styles', 'images'], function () {
});

gulp.task('build:dev', ['jekyll:dev', 'styles', 'images'], function () {
});

// Builds your site with the 'build' command and then runs all the optimizations on
// it and outputs it to './site'
gulp.task('publish', ['build', 'clean:prod'], function () {
    gulp.start('html', 'copy');
});

gulp.task('dev', ['serve:dev','build:dev']);

// Optimizes the images that exists
gulp.task('optimize-photos', function () {

  var post = options.post || "**";
  return gulp.src('static/' + post + '/*.jpg')
  //return gulp.src('src/assets/**/*.png')
    .pipe($.plumber())
    .pipe($.imagemin({
      // Runs 16 trials on the PNGs to better the optimization
      // Can by anything from 1 to 7, for more see
      // https://github.com/sindresorhus/gulp-imagemin#optimizationlevel-png
      optimizationLevel: 4,
      // Lossless conversion to progressive JPGs
      progressive: true,
      // Interlace GIFs for progressive rendering
      interlaced: true
    }))
    .pipe($.size({title: 'Images'}))
    .pipe(gulp.dest('static/'+post));
});

gulp.task('post', shell.task(['bundle exec ruby gen.rb'], {cwd: 'tools/gcmd'}));



function invalidate(paths, callback) {
    var cf = cloudfront.createClient(process.env.AWS_S3_KEY, process.env.AWS_S3_SECRET);
    cf.getDistribution('ESYZ2T10RQQ38', function(err, distribution) {
      if (err) {
        callback(err);
        return;
      }

      distribution.invalidate(_.now(), paths, function(err, invalidation) {
        if (err) {
          callback(err);
          return;
        }

        console.log(invalidation);
        callback(null, invalidation);
      })
    });
}

var invalidationSets = {
  styles: function(){
    return ['/assets/stylesheets/style.min.css', '/assets/stylesheets/style.custom.min.css'];
  },
  scripts: function(){
    return ['/assets/javascript/c.min.js', '/assets/javascript/all.min.js'];
  },
  getPost: function(file){
    return "/" + file.match('\\d{4}-\\d{2}-\\d{2}-(.+)\\.md')[1] + "/"
  },
  lastPost: function(){
    var files = glob.sync("src/_posts/*.md");
    return [this.getPost(files[files.length - 1])];
  },
  prevPost: function(){
    var files = glob.sync("src/_posts/*.md");
    return [this.getPost(files[files.length - 2])];
  },
  xml: function() {
    return ['/feed.xml', '/sitemap.xml']
  }
};

function invalidateSets(){
  var arrays = _.filter(arguments, _.isArray);
  var callback = _.first(_.filter(arguments, _.isFunction));
  invalidate(_.uniq(_.flatten(arrays)), callback)
}




gulp.task('invalidate', function(done){
  //invalidateSets(["/vipassana-v-tailande/"], done);
  // invalidateSets(invalidationSets.scripts(), invalidationSets.styles(), done);
  invalidateSets(['/'], invalidationSets.lastPost(), invalidationSets.prevPost(), invalidationSets.xml(), done);
});

gulp.task('ping-sitemap', function(done){
  var requests = [
    "http://www.bing.com/ping?sitemap=",
    "http://www.google.com/ping?sitemap=",
    //"http://webmaster.yandex.com/site/map.xml?host="
  ];
  Promise.all(requests.map(function(r){
    return rp(r + "http://gaziga.com/sitemap.xml");
  })).then(function(results) {
    console.log(results);
  }).finally(done);
});
