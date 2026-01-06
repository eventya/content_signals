# frozen_string_literal: true

# Test models
class Page < ActiveRecord::Base
  has_many :page_views, as: :trackable, class_name: "ContentSignals::PageView"
end

class Profile < ActiveRecord::Base
  has_many :page_views, as: :trackable, class_name: "ContentSignals::PageView"
end

class User < ActiveRecord::Base
end
