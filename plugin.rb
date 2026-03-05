# frozen_string_literal: true

# name: discourse-digest-disable-trim
# about: Disables trimming of topic text excerpts used in digest emails (passes full cooked HTML to email formatter) based on configurable mode.
# version: 1.4.0
# authors: you
# required_version: 3.0.0

enabled_site_setting :digest_disable_trim_enabled

after_initialize do
  module ::DigestDisableTrim
    PLUGIN_NAME = "discourse-digest-disable-trim"

    def self.parse_tags_csv(csv)
      csv.to_s
         .split(",")
         .map { |t| t.strip.downcase }
         .reject { |t| t.empty? }
         .uniq
    end

    def self.topic_has_any_tag?(topic, wanted_tags_downcased)
      return false if topic.nil?
      return false if wanted_tags_downcased.nil? || wanted_tags_downcased.empty?

      # topic.tags is commonly available; if not preloaded it may query (acceptable here)
      topic.tags.any? { |tg| wanted_tags_downcased.include?(tg.name.to_s.downcase) }
    rescue
      false
    end

    module UserNotificationsHelperPatch
      def email_excerpt(html_arg, post = nil)
        return super unless SiteSetting.digest_disable_trim_enabled

        mode = SiteSetting.digest_disable_trim_mode.to_s

        disable_trim =
          case mode
          when "count"
            max_topics = SiteSetting.digest_disable_trim_max_popular_topics.to_i
            max_topics > 0 &&
              defined?(@popular_topics) &&
              @popular_topics.respond_to?(:size) &&
              @popular_topics.size.to_i <= max_topics

          when "tags"
            wanted = ::DigestDisableTrim.parse_tags_csv(SiteSetting.digest_disable_trim_tags_csv)
            topic = post&.respond_to?(:topic) ? post.topic : nil
            ::DigestDisableTrim.topic_has_any_tag?(topic, wanted)

          else
            # Unknown mode => behave like stock Discourse
            false
          end

        if disable_trim
          html = html_arg.to_s
          return PrettyText.format_for_email(html, post).html_safe
        end

        super
      end
    end
  end

  ::UserNotificationsHelper.prepend(::DigestDisableTrim::UserNotificationsHelperPatch)
end
