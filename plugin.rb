# frozen_string_literal: true
# name: discourse-image-filter
# about: A plugin to restrict uploading explicit content based on set criteria
# version: 0.1
# authors: fzngagan@gmail.com

enabled_site_setting :image_filter_enabled

gem 'os', '1.1.1', require: true
gem_platform = OS.linux? ? 'x86_64-linux' : OS.mac? ? 'universal-darwin' : ''
## if the platform is other than linux or mac, this will fail loudly
gem 'google-protobuf', '3.13.0', platform: gem_platform, require: false
gem 'googleapis-common-protos-types', '1.0.5', require: false
gem 'grpc', '1.31.1', platform: gem_platform, require: false
gem 'googleapis-common-protos', '1.3.10', require: false
gem 'signet', '0.14.0', require: false
gem 'memoist', '0.16.2', require: false
gem 'googleauth', '0.13.1', require: false
gem 'rly', '0.2.3', require: false
gem 'google-gax', '1.8.1', require: false
gem 'google-cloud-vision', '0.38.0', require: false

require 'google/cloud/vision/v1'

module ::DiscourseImageFilter
  CATEGORIES = ["adult", "spoof", "medical", "violence", "racy"]

  LIKELIHOOD_VALUES = Google::Cloud::Vision::V1::Likelihood.constants.map do |v|
    [v, Google::Cloud::Vision::V1::Likelihood.const_get(v)]
  end.to_h

  LIKELIHOOD_VALUES[:OFF] = 1000

  class ImageUploadAnnotator
    def initialize(image_path)
      @image_path = image_path
    end

    def annotate
      image_annotator = Google::Cloud::Vision::V1::ImageAnnotator.new
      image_annotator.safe_search_detection image: @image_path
    end

    def detect_violations
      response = annotate
      violations = Set.new
      response.responses.each do |res|
        safe_search = res.safe_search_annotation

        CATEGORIES.each do |category|
          if (LIKELIHOOD_VALUES[safe_search.send(category)] > SiteSetting.send("if_#{category}_max_acceptable"))
            violations << category
          end
        end
      end

      violations
    end
  end
end

load File.expand_path('../app/models/explicit_content_setting.rb', __FILE__)

after_initialize do
  on(:before_upload_creation) do |file, is_image|
    if is_image
      annotator = ::DiscourseImageFilter::ImageUploadAnnotator.new(file.path)
      violations = annotator.detect_violations
      if (violations.present?)
        raise StandardError.new(I18n.t('content_violation_error', violations: violations.to_a * ", "))
      end
    end
  end
end
