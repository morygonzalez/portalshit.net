FactoryGirl.define do
  create_time = update_time = Time.parse("2011-01-09T05:39:08Z")

  factory :user do
    sequence(:name){|n| "testuser#{n}" }
    hashed_password '6338db2314bba79531444996b780fa7036480733'
    salt '2Z4H4DzATC'
    permission_level 1
    created_at create_time
    updated_at update_time
  end
end
