# frozen_string_literal: true

require 'rails_helper'
require "#{Rails.root}/lib/analytics/course_statistics"

describe CourseStatistics do
  let(:course_ids) { [1, 2, 3, 10001, 10002, 10003] }

  before do
    course_ids.each do |i|
      # Course
      id = i
      id2 = id + 100
      create(:course, id:, start: 1.year.ago, end: Time.zone.today, slug: "foo/#{id}")
      # First user in course working within course dates
      create(:user, id:, username: "user#{id}")
      create(:courses_user, id:, user_id: id, course_id: id, role: 0)
      create(:revision, date: 1.day.ago, article_id: id, user_id: id, characters: 1000)
      create(:article, id:, title: "Article_#{id}", namespace: Article::Namespaces::MAINSPACE)
      create(:commons_upload, id:, user_id: id, uploaded_at: 1.day.ago, usage_count: 1)

      # Second user in course working outside course dates
      create(:user, id: id2, username: "second_user#{id}")
      create(:courses_user, id: id2, user_id: id2, course_id: id2, role: 0)
      create(:revision, date: 2.years.ago, article_id: id2, user_id: id2)
      create(:article, id: id2, title: "Article_#{id2}")
      create(:commons_upload, id: id2, user_id: id2, uploaded_at: 2.years.ago, usage_count: 1)
      CoursesUsers.update_all_caches(CoursesUsers.ready_for_update)
    end
  end

  describe '#report_statistics' do
    let(:subject) { described_class.new(course_ids).report_statistics }

    it 'works for empty campaigns' do
      output = described_class.new([]).report_statistics
      expect(output[:course_count]).to eq(0)
      expect(output[:students_excluding_instructors]).to eq(0)
    end

    it 'counts articles, revisions and uploads from during courses' do
      expect(subject[:course_count]).to eq(course_ids.count)
      expect(subject[:students_excluding_instructors]).to eq(course_ids.count)
      expect(subject[:file_uploads]).to eq(course_ids.count)
      expect(subject[:revisions]).to eq(course_ids.count)
      expect(subject[:articles_edited]).to eq(course_ids.count)
      expect(subject[:file_uploads]).to eq(course_ids.count)
      expect(subject[:files_in_use]).to eq(course_ids.count)
      expect(subject[:global_usages]).to eq(course_ids.count)
      expect(subject[:characters_added]).to be > 0
      expect(subject[:words_added]).to be > 0
    end

    it 'counts only tracked revisions and articles' do
      create(:articles_course, course_id: 1, article_id: 1, tracked: false)
      CoursesUsers.update_all_caches(CoursesUsers.where(id: 1))
      expect(subject[:articles_edited]).to eq(course_ids.count - 1)
      expect(subject[:revisions]).to eq(course_ids.count - 1)
      expect(subject[:characters_added]).to eq(5000) # Characters added should be reduced from 6000
    end
  end

  describe '#articles_edited' do
    it 'works for empty campaigns' do
      output = described_class.new([]).articles_edited
      expect(output).to be_empty
    end

    it 'returns articles edited during courses' do
      output = described_class.new(course_ids).articles_edited
      expect(output).to include(Article.find(1))
      expect(output).not_to include(Article.find(101))
    end
  end
end
