require 'nokogiri'
require 'htmlentities'
require 'babosa'
require_relative 'helpers/image_helper'
require 'html_truncator'
require 'russian'

HTML_Truncator.punctuation_chars.delete '.'

module Jekyll
  module GazigaFilter

    @@months = {1 => "января", 2 => "февраля", 3 => "марта", 4 => "апреля", 5 => "мая", 6 => "июня", 7 => "июля", 8 => "августа", 9 => "сентября", 10 => "октября", 11 => "ноября", 12 => "декабря", }
    @@months_names = {1 => "Январь", 2 => "Февраль", 3 => "Март", 4 => "Апрель", 5 => "Май", 6 => "Июнь", 7 => "Июль", 8 => "Август", 9 => "Сентябрь", 10 => "Октябрь", 11 => "Ноябрь", 12 => "Декабрь", }
    @@conf = Jekyll.configuration({})

    def format_date(input)
        "#{input.strftime("%d #{@@months[input.month]} %Y")}"
    end

    def month_name(input)
      @@months_names[input].capitalize
    end

    def is_post?(input)
        input.start_with? '_posts/'
    end

    def thumb_sm(input)
      ImageHelper.instance.thumb_sm(input)
    end

    def thumb_lg(input)
      ImageHelper.instance.thumb_lg(input)
    end

    def get_email(author)
      if author == 'uma'
        'homoparadoksuma@gmail.com'
      else
        'gagrych@gmail.com'
      end
    end

    def geo_from_url(input)
      if input =~ /\/geo\/(.+)\//i
        return $1
      end
    end

    def decode(input)
      HTMLEntities.new.decode input
    end

    def encode_uri_component(input)
        URI.escape(input, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))
    end

    def strip_html(input)
       input.gsub('. ', ".").gsub('.', ". ").gsub(/<\/?[^>]*>/, "")
    end

    def excerpt(input)
      strip_html HTML_Truncator.truncate(input, 250, :length_in_chars => true).gsub(/\r\n?/, ' ')
    end

    def no_slash(input)
      input.gsub(/^\//, '')
    end

    def self.slugify(input)
      input.gsub(/_|\P{Word}/, '-').gsub(/-{2,}/, '-').downcase.to_slug.truncate(40).transliterate(:russian).normalize.to_s.chomp('/') + '/'
    end

    def translate(input)
        @context.registers[:site].data["translations"][input] || input
    end

    def group_by_date(coll, field = nil)
      if field
        coll.group_by { |i| i.date.send(field) }
      else
        coll.group_by { |i| i.date }
      end
    end

    def order(coll, field = nil)
        if field
            coll.sort_by { |i| translate(i[field]) }
        else
            coll.sort_by { |i| translate(i) }
        end
    end

    def exclude_prev_next(coll)
        coll.reject{ |i|
            page['previous'] && page['previous']['id'] == i.id || page['next'] && page['next']['id'] == i.id
        }
    end

    def local_urls(coll)
      coll.reject{ |i|
        i.start_with?('http')
      } if coll
    end

    def remote_urls(coll)
      coll.select{ |i|
        i.start_with?('http')
      } if coll
    end

    def page
        @context.environments.first['page']
    end

    def furl(input)
      return input.chomp('/') + '/' #input.chomp(File.extname(input))
    end

    def normalize(input)
      return GazigaFilter.slugify(input)
    end

    def prepare_tags(tags)
      # ,href:'/tags/#{normalize(t[0])}'
      "[" + tags.map { |t| "{text:'#{t[0]}',size:#{10 + Math.sqrt(t[1].size) * 5},href:'/tags/#{normalize(t[0])}'}" }.join(",") + "]"
    end

    def dropbox(post, img_name)
      File.join(@@conf['dropbox'], 'posts', post, img_name)
    end

    def get_host(url)
      begin
        return nil? if url.start_with?('#')
        url = "http://#{url}" if URI.parse(url).scheme.nil?
        host = URI.parse(url).host
        return nil if host.nil?
        host = URI.parse(url).host.downcase
        host.start_with?('www.') ? host[4..-1] : host
      rescue URI::InvalidURIError
        return nil
      end
    end

    def post_res(input)
      @@conf['url'] + '/' + File.join(page['url'].to_s.split('/').last, input)
      #dropbox(post, input)
      # input
    end


    def get_ratio(img)
        size = get_img_size img
        (100.0*size[1])/size[0]
    end

    def half?(img)
        size = get_img_size img
        get_ratio(img) > 80 || size[0] < 495
    end

    def prev_node(img)
        prev_sibling = img.previous_sibling
        prev_sibling = prev_sibling.previous_sibling while !prev_sibling.nil? and (prev_sibling.to_html.strip == '' || prev_sibling.to_html.strip == "\n" || prev_sibling.to_html.strip == "\n\r" || prev_sibling.name == 'br')
        prev_sibling
    end

    def group_images(doc)
        groups = []

        doc.xpath("//img").each do |img|
            prev = prev_node(img)
            if half?(img) && prev && prev.name == 'img' && half?(prev)
                groups.last << img
            else
                groups << [img]
            end
        end
        groups
    end

    def pluralize(input)
        Russian::pluralize(input)
    end

    def get_post
        furl page['url'].to_s.split('/').last
    end

    def get_img_size(img)
        img_name = img['src'].split('/').last
        img_url = post_res(img_name)
        # puts "Resolving image size: #{img_url}"
        size = ImageHelper.instance.size(img_url, get_post, img_name)
        # raise "Size not resolved" unless size
        # puts size
        return size
    end

    def wrap_img(img)
        img['id'] = File.basename(img['src'].split('/').last, '.jpg')
        "<div class='pw' style='padding-top:#{get_ratio(img).round(2)}%;'>#{img.to_html}</div>"
    end


    def wrap_group_img(group)
        '<div class=pwr>' + group.map{|p| "<div class='half'>#{wrap_img(p)}</div>"}.join + '</div>'
    end

    def process_img(input)
      doc = Nokogiri::HTML(input)
      groups = group_images(doc)


      groups.each do |group|

          if group.count == 1
              img = group[0]
              img_name = img['src'].split('/').last
              img['src'] = img_name
              img.replace(Nokogiri.make(wrap_img img))
          else
              group.each_slice(2) {|pair|
                  pair[0].replace Nokogiri.make(wrap_group_img(pair))
                  pair[1].remove if pair.count > 1
              }
          end

      end
      doc.xpath("//a").each do |a|
        if a['href'] =~ /jpg$/
          img_name = a['href'].split('/').last
          a['href'] = post_res(img_name)
        else
          url = a['href'].chomp('/')
          host = get_host(url)
          if File.extname(url) == '' && (host.to_s == '' || host == 'gaziga.com')
            a['href'] = url + '/'
          end
        end
      end

      return doc.css('body').inner_html
    end
  end
end

Liquid::Template.register_filter(Jekyll::GazigaFilter)


