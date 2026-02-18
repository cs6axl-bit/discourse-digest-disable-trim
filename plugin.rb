# frozen_string_literal: true

# name: discourse-digest-disable-trim
# about: Disables trimming of topic text excerpts used in digest emails (passes full cooked HTML to email formatter) only when digest has exactly 1 popular topic
# version: 1.2.0
# authors: you
# required_version: 3.0.0

after_initialize do
  module ::DigestDisableTrim
    module UserNotificationsHelperPatch
      def email_excerpt(html_arg, post = nil)
        if defined?(@popular_topics) && @popular_topics.respond_to?(:size) && @popular_topics.size < 3
          html = html_arg.to_s
          return PrettyText.format_for_email(html, post).html_safe
        end

        super
      end
    end
  end

  ::UserNotificationsHelper.prepend(::DigestDisableTrim::UserNotificationsHelperPatch)
end
