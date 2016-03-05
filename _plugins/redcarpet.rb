# This file contains overrides for markdown generation.
#
# Redcarpet is the original markdown parser and generator. It contains a class called
# Redcarpet::Render::HTML which is used to generate HTML from markdown. We add a few
# more useful features here.

require 'redcarpet'

module Jekyll
  class Node
    attr_accessor :child
    attr_accessor :sibling
    attr_accessor :parent
    attr_accessor :text
    attr_accessor :url

    def initialize text, parent=nil, sibling=nil, child=nil, url=nil
      @parent = parent
      @text = text
      @sibling = sibling
      @child = child
      @url = url
    end

    def level
      level = 1
      current = @parent
      until current.nil? do
        current = current.parent
        level = level + 1
      end
      level
    end

    def slug
      @text.to_s.gsub(/\W/, "_").downcase
    end
  end
end

module Redcarpet
  module Render
    class HTMLOutline < HTML
      attr_accessor :outline
      attr_accessor :title

      def initialize(*args)
        @outline ||= Jekyll::Node.new(:root)
        @last    ||= @outline
        @title   ||= ""

        super *args
      end

      # Headers (h1, h2, etc) to contain slug tags
      def header(text, header_level, *args)
        if header_level > 1
          new_node = Jekyll::Node.new text
          if header_level == @last.level
            new_node.parent = @last.parent
            @last.sibling = new_node
          elsif header_level > @last.level
            new_node.parent = @last
            @last.child = new_node
          elsif header_level < @last.level
            new_node.parent = @last.parent.parent
            @last.parent.sibling = new_node
          end
          @last = new_node

          "<h#{header_level} id='#{new_node.slug}'>#{text}</h#{header_level}>"
        elsif header_level == 1
          @title = text
          "<h#{header_level} class='big' id='top'>#{text}</h#{header_level}>"
        end
      end

      def link(url, title, content)
        "<a href='#{url}' title='#{title}'>#{content}</a>"
      end
    end

    class HTML
      # Fix issue with dashes inside codespans.
      def codespan(code)
        "<code>#{CGI::escapeHTML(code).gsub(/\-/, "&#8209;")}</code>"
      end

      # Allow image captions, borders, and youtube embeds.
      def image(link, title, alt_text)
        unless link.match /^http|^\//
          link = "/images/#{@slug}/#{link}"
        end

        options = alt_text.match(/^(.*)\|/)
        options = options[1] if options

        alt_text.gsub!(/^.*\|/, "")

        styles      = ""
        img_styles  = ""
        classes     = "image"
        img_classes = ""

        if options
          options.split('|').each do |option|
            value = ""
            if option.index('=')
              option, value = option.split('=')
            end
            case option
            when "class"
              img_classes << value
            when "border"
              classes << " border"
            when "right"
              classes << " right"
            when "left"
              classes << " left"
            when "clear"
              styles << "clear: both;"
            when "width"
              unless value.end_with?("px")
                value = value + "px"
              end
              img_styles << "width: #{value};"
            when "fullwidth"
              classes << " fullwidth"
            end
          end
        end

        caption = ""
        caption = alt_text unless alt_text.start_with? "!"
        alt_text.gsub!(/^\!/, "")

        caption = Redcarpet::Markdown.new(self.class.new()).render(caption)
        alt_text = Nokogiri::HTML(alt_text).xpath("//text()").remove

        img_source = "<img src='#{link}' class='#{img_classes}' style='#{img_styles}' title='#{title}' alt='#{alt_text}' />"

        if link.match "http[s]?://(www.)?youtube.com"
          # embed the youtube link
          youtube_hash = link.match("youtube.com/.*=(.*)$")[1]
          img_source = "<div class='youtube'><div class='youtube_fixture'><img src='/images/youtube_placeholder.png' /><iframe class='youtube_frame' src='http://www.youtube.com/embed/#{youtube_hash}'></iframe></div></div>"
        end

        caption = "<br /><div class='caption'>#{caption}</div>" unless caption == ""
        "</p><div style='#{styles}' class='#{classes}'>#{img_source}#{caption}</div><p>"
      end
    end
  end
end

class Jekyll::Converters::Markdown::CustomRedcarpet
  def initialize(config)
    @config = config
  end

  def extensions
    hash = Hash[ *@config['redcarpet']['extensions'].map {|e| [e.to_sym, true] }.flatten ]
    hash[:fenced_code_blocks] = true
    hash[:smartypants] = true
    hash
  end

  def markdown
    @renderer = ::Redcarpet::Render::HTMLOutline.new(self.extensions)
    @markdown = ::Redcarpet::Markdown.new(@renderer, self.extensions)
  end

  def documentation_nav_impl(outline)
    return "" if outline.nil?
    if outline.url
      "<li><a href='#{outline.url}'>#{outline.text}</a></li>#{documentation_nav_impl(outline.sibling)}"
    else
      "<li><a href='##{outline.slug}'>#{outline.text}</a></li>#{documentation_nav_impl(outline.sibling)}"
    end
  end

  def documentation_nav
    "<ul id='sidebar' class='nav nav-stacked'>" + documentation_nav_impl(@renderer.outline.child) + "</ul>"
  end

  def convert(content)
    "<div class='content'><article>" + self.markdown.render(content) + "</article></div><div class='clear'></div>"
  end
end
