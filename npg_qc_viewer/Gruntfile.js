module.exports = function(grunt) {
  "use strict";
  require( 'load-grunt-tasks' )( grunt );

  grunt.initConfig({
    jsonlint: {
      pkg: {
        src: ['package.json', '.jscsrc', '.jshintrc']
      }
    },
    jscs: {
      main: [
        'Gruntfile.js',
        'root/static/scripts/collapse.js',
      ],
      options: {
        config: '.jscsrc'
      }
    },
    jshint: {
      all: [
        'Gruntfile.js',
        'root/static/scripts/collapse.js',
        'root/static/scripts/qcoutcomes/qc_outcomes_view.js',
        't/client/test*.js'
      ],
      options: {
        jshintrc: '.jshintrc'
      }
    },
    qunit: {
      options: {
        timeout: 5000,
        console: true,
        '--debug': true,
      },
      all: ['t/client/test*.html'],
    },
    watch: {
      js: {
        files:[
          'Gruntfile.js',
          '.jshintrc',
          '.jscsrc',
          'root/static/scripts/**/*.js',
          't/client/test*.js',
          't/client/test*.html',
        ],
        tasks: [
          'test'
        ]
      }
    },
  });

  grunt.registerTask('lint', ['jsonlint', 'jshint', 'jscs']);
  grunt.registerTask('test', 'Run tests', function( pattern ) {
    if ( !!pattern ) {
      if ( !pattern.startsWith('t/client/') ) {
        pattern = 't/client/' + pattern;
      }
      grunt.config.set('qunit.all', [pattern]);
      grunt.task.run('qunit:all');
    } else {
      grunt.task.run(['lint', 'qunit']);
    }
  });
  grunt.registerTask('default', ['test']);
};

