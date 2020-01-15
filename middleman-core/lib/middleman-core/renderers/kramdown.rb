require 'kramdown'

module Middleman
  module Renderers
    # Our own Kramdown Tilt template that simply uses our custom renderer.
    class KramdownTemplate < ::Tilt::KramdownTemplate
      def initialize(*args, &block)
        super

        @context = @options[:context] if @options.key?(:context)
      end

      def evaluate(context, *)
        MiddlemanKramdownHTML.scope = @context || context

        @output ||= begin
          output, warnings = MiddlemanKramdownHTML.convert(@engine.root, @engine.options)
          @engine.warnings.concat(warnings)
          output
        end
      end
    end

    # Custom Kramdown renderer that uses our helpers for images and links
    class MiddlemanKramdownHTML < ::Kramdown::Converter::Html
      cattr_accessor :scope

      def convert_img(el, _)
        attrs = el.attr.dup

        link = attrs.delete('src')
        scope.image_tag(link, attrs)
      end

      def convert_a(el, indent)
        content = inner(el, indent)

        if el.attr['href'].start_with?('mailto:')
          mail_addr = el.attr['href'].sub(/\Amailto:/, '')
          href = obfuscate('mailto') << ':' << obfuscate(mail_addr)
          content = obfuscate(content) if content == mail_addr
          return %(<a href="#{href}">#{content}</a>)
        end

        attr = el.attr.dup
        link = attr.delete('href')

        # options to link_to are expected to be symbols, but in Markdown
        # everything is a string.
        attr.transform_keys!(&:to_sym)

        scope.link_to(content, link, attr)
      end

      def convert_html_element(el, indent)
        res = inner(el, indent)
        if el.options[:category] == :span
          "<#{el.value}#{html_attributes(el.attr)}" + \
            (res.empty? && HTML_ELEMENTS_WITHOUT_BODY.include?(el.value) ? " />" : ">#{res}</#{el.value}>")
        else
          output = +''
          if @stack.last.type != :html_element || @stack.last.options[:content_model] != :raw
            output << ' ' * indent
          end

          # PATCH: If an <a> or <iframe>, rewrite the URL to match a known
          # resource, if possible
          attrs =
            if el.value == "a"
              Middleman::Logger.singleton.debug "== (a) Resolving URL: #{scope.asset_url(el.attr["href"])}"
              el.attr.merge(
                "href" => scope.asset_url(el.attr["href"])#, "", relative: true)
              )
            elsif el.value == "iframe"
              Middleman::Logger.singleton.debug "== (iframe) Resolving URL: #{scope.asset_url(el.attr["src"])}"
              el.attr.merge(
                "src" => scope.asset_url(el.attr["src"])#, "", relative: true)
              )
            else
              el.attr
            end

          output << "<#{el.value}#{html_attributes(attrs)}"
          if el.options[:is_closed] && el.options[:content_model] == :raw
            output << " />"
          elsif !res.empty? && el.options[:content_model] != :block
            output << ">#{res}</#{el.value}>"
          elsif !res.empty?
            output << ">\n#{res.chomp}\n" << ' ' * indent << "</#{el.value}>"
          elsif HTML_ELEMENTS_WITHOUT_BODY.include?(el.value)
            output << " />"
          else
            output << "></#{el.value}>"
          end
          output << "\n" if @stack.last.type != :html_element || @stack.last.options[:content_model] != :raw
          output
        end
      end
    end
  end
end
