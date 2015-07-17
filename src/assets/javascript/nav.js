'use strict';
/* global $ */
$(document).ready(function() {
    var menu = $('#navigation-menu');
    var menuToggle = $('#js-mobile-menu');

    $(menuToggle).on('click', function(e) {
        e.preventDefault();
        menu.slideToggle(function(){
            if(menu.is(':hidden')) {
                menu.removeAttr('style');
            }
        });
    });

    // underline under the active nav item
    $('.nav .nav-link').click(function() {
        $('.nav .nav-link').each(function() {
            $(this).removeClass('active-nav-item');
        });
        $(this).addClass('active-nav-item');
        $('.nav .more').removeClass('active-nav-item');
    });

    $('.search-input').keydown(function(e){
        if(e.which == 13) {
          var q = $(e.target).val();
          if (!q || !q.trim())
            return;
          window.location.href = "https://www.google.com/search?q=site:gaziga.com " + escape(q);
        }
    });
});
