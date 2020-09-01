# frozen_string_literal: true

require_dependency 'enum_site_setting'
class ExplicitContentSetting < EnumSiteSetting

  def self.valid_value?(val)
   valid_values.include?(val)
  end

  def self.values
    ::DiscourseImageFilter::LIKELIHOOD_VALUES.map do |key, value|
      {name: key.to_s.humanize, value: value}
    end
  end

  def self.valid_values
    ::DiscourseImageFilter::LIKELIHOOD_VALUES.values
  end

  private_class_method :valid_values
end
