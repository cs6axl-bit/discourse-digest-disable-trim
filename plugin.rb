# frozen_string_literal: true

# name: discourse-digest-disable-trim
# about: Disables trimming of topic text excerpts used in digest emails (passes full cooked HTML to email formatter)
# version: 1.0.0
# authors: you
# required_version: 3.0.0

after_initialize do
  # Core trims digest excerpts via UserNotificationsHelper#email_excerpt
  # (it uses first_paragraphs_from(...) before PrettyText.format_for_email).
  # We override it to pass the full html_arg through untrimmed.
  module ::DigestDisableTrim
    module UserNotificationsHelperPatch
      def email_excerpt(html_arg, post = nil)
        html = html_arg.to_s
        PrettyText.format_for_email(html, post).html_safe
      end
    end
  end

  ::UserNotificationsHelper.prepend(::DigestDisableTrim::UserNotificationsHelperPatch)
end
