class User < ActiveRecord::Base
  ROLES = %w[superadmin admin volunteer]

  TEMP_EMAIL_PREFIX = 'change@me'
  TEMP_EMAIL_REGEX = /\Achange@me/

  devise :database_authenticatable, :registerable, :recoverable,
         :rememberable, :trackable, :validatable, :omniauthable, :confirmable

  attr_accessible :email, :password, :password_confirmation, :remember_me, :role,
                  :first_name, :last_name, :city, :country, :bio

  validates_format_of :email, :without => TEMP_EMAIL_REGEX, on: :update
  validates_presence_of :first_name, :last_name

  after_create :assign_default_role
  before_save :capitalize_fields

  has_many :translations
  has_many :translation_videos, :through => :translations, :source => :video

  def full_name
    "#{first_name} #{last_name}"
  end

  def untranslated_videos
    self.translation_videos.select { |video| not video.translated? }
  end
  def translated_videos
    self.translation_videos.select { |video| video.translated? }
  end

  def is?(role)
    role.to_s == self.role
  end

  def assign_default_role
    self.role ||= 'volunteer'
    self.save
  end

  def email_verified?
    self.email && self.email !~ TEMP_EMAIL_REGEX
  end

  def self.find_for_oauth(auth, signed_in_resource = nil)
    identity = Identity.find_for_oauth(auth)

    user = signed_in_resource ? signed_in_resource : identity.user

    if user.nil?
      # Get the existing user by email:
      email = auth.info.email
      user = User.where(:email => email).first if email

      # Create the user if it's a new registration:
      if user.nil?
        full_names = auth.info.name.rpartition(' ')
        user = User.new(
          :email => email ? email : "#{TEMP_EMAIL_PREFIX}-#{auth.uid}-#{auth.provider}.com",
          :password => Devise.friendly_token[0, 20],
          :first_name => full_names.first,
          :last_name => full_names.last
        )
        user.skip_confirmation! if user.respond_to?(:skip_confirmation)
        user.save!
      end
    end

    # Associate the identity with the user if needed:
    if identity.user != user
      identity.user = user
      identity.save!
    end
    user
  end

  private
  def capitalize_fields
    write_attribute(:first_name, first_name.titleize)
    write_attribute(:last_name, last_name.titleize)

    write_attribute(:country, country.titleize) if country
    write_attribute(:city, city.titleize) if city
  end
end
