# frozen_string_literal: true

# name: discourse-digest-disable-trim
# about: Disable trimming of topic text for digest emails, optionally only for the first topic
# version: 1.2.0
# authors: you
# required_version: 3.0.0

enabled_site_setting :digest_disable_trim_enabled
enabled_site_setting :digest_disable_trim_first_topic_only

after_initialize do
  module ::DigestDisableTrim
    THREAD_FLAG  = :_ddt_active
    THREAD_COUNT = :_ddt_excerpt_count

    def self.active?
      Thread.current[THREAD_FLAG] == true
    end

    def self.reset_counter!
      Thread.current[THREAD_COUNT] = 0
    end

    def self.next_index!
      Thread.current[THREAD_COUNT] ||= 0
      idx = Thread.current[THREAD_COUNT]
      Thread.current[THREAD_COUNT] = idx + 1
      idx
    end

    def self.with_flag
      prev_flag  = Thread.current[THREAD_FLAG]
      prev_count = Thread.current[THREAD_COUNT]
      Thread.current[THREAD_FLAG] = true
      Thread.current[THREAD_COUNT] = 0
      yield
    ensure
      Thread.current[THREAD_FLAG]  = prev_flag
      Thread.current[THREAD_COUNT] = prev_count
    end
  end

  class ::UserNotifications
    alias_method :_ddt_orig_digest, :digest

    def digest(user, opts = {})
      return _ddt_orig_digest(user, opts) unless SiteSetting.digest_disable_trim_enabled

      ::DigestDisableTrim.with_flag do
        _ddt_orig_digest(user, opts)
      end
    end
  end

  module ::DigestDisableTrim
    module UserNotificationsHelperPatch
      # Keep a cap to avoid massive emails; set to 0 to disable cap.
      MAX_COOKED_CHARS = 25_000

      def email_excerpt(html_arg, post = nil)
        return super unless ::DigestDisableTrim.active?

        idx = ::DigestDisableTrim.next_index!

        # If "first topic only" is enabled, only bypass trimming on the first excerpt call
        if SiteSetting.digest_disable_trim_first_topic_only && idx > 0
          return super
        end

        html = html_arg.to_s
        if MAX_COOKED_CHARS > 0 && html.length > MAX_COOKED_CHARS
          html = html[0, MAX_COOKED_CHARS]
        end

        PrettyText.format_for_email(html, post).html_safe
      end
    end
  end

  ::UserNotificationsHelper.prepend(::DigestDisableTrim::UserNotificationsHelperPatch)
end
