#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) 2012-2024 the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

require 'spec_helper'
RSpec.describe Project, 'customizable' do
  let!(:section) { create(:project_custom_field_section) }

  let!(:bool_custom_field) do
    create(:boolean_project_custom_field, project_custom_field_section: section)
  end
  let!(:text_custom_field) do
    create(:text_project_custom_field, project_custom_field_section: section)
  end
  let!(:list_custom_field) do
    create(:list_project_custom_field, project_custom_field_section: section)
  end

  context 'when not persisted' do
    let(:project) { build(:project) }

    describe '#available_custom_fields' do
      it 'returns all existing project custom fields as available custom fields' do
        expect(project.project_custom_field_project_mappings)
          .to be_empty
        expect(project.project_custom_fields)
          .to be_empty
        # but:
        expect(project.available_custom_fields)
          .to contain_exactly(bool_custom_field, text_custom_field, list_custom_field)
      end
    end
  end

  context 'when persisted' do
    let(:project) { create(:project) }

    describe '#active_custom_field_ids_of_project' do
      it 'returns all active custom field ids of the project' do
        expect(project.active_custom_field_ids_of_project)
          .to be_empty
      end
    end

    describe '#available_custom_fields' do
      it 'returns only mapped project custom fields as available custom fields' do
        expect(project.project_custom_field_project_mappings)
          .to be_empty
        expect(project.project_custom_fields)
          .to be_empty
        # and thus:
        expect(project.available_custom_fields)
          .to be_empty

        project.project_custom_fields << bool_custom_field

        expect(project.available_custom_fields)
          .to contain_exactly(bool_custom_field)
      end
    end

    describe '#custom_field_values and #custom_value_for' do
      context 'when no custom fields are mapped to this project' do
        it '#custom_value_for returns nil' do
          expect(project.custom_value_for(text_custom_field))
            .to be_nil
          expect(project.custom_value_for(bool_custom_field))
            .to be_nil
          expect(project.custom_value_for(list_custom_field))
            .to be_nil
        end

        it '#custom_field_values returns an empty hash' do
          expect(project.custom_field_values)
            .to be_empty
        end
      end

      context 'when custom fields are mapped to this project' do
        before do
          project.project_custom_fields << [text_custom_field, bool_custom_field]
          project.reload # TODO: why is this necessary?
        end

        it '#custom_field_values returns a hash of mapped custom fields with nil values' do
          text_custom_field_custom_field_value = project.custom_field_values.find do |custom_value|
            custom_value.custom_field_id == text_custom_field.id
          end

          expect(text_custom_field_custom_field_value).to be_present
          expect(text_custom_field_custom_field_value.value).to be_nil

          bool_custom_field_custom_field_value = project.custom_field_values.find do |custom_value|
            custom_value.custom_field_id == bool_custom_field.id
          end

          expect(bool_custom_field_custom_field_value).to be_present
          expect(bool_custom_field_custom_field_value.value).to be_nil
        end

        context 'when values are set for mapped custom fields' do
          before do
            project.custom_field_values = {
              text_custom_field.id => 'foo',
              bool_custom_field.id => true
            }
          end

          it '#custom_value_for returns the set custom values' do
            expect(project.custom_value_for(text_custom_field).typed_value)
              .to eq('foo')
            expect(project.custom_value_for(bool_custom_field).typed_value)
              .to be_truthy
            expect(project.custom_value_for(list_custom_field).typed_value)
              .to be_nil
          end

          it '#custom_field_values returns a hash of mapped custom fields with their set values' do
            expect(project.custom_field_values.find do |custom_value|
                     custom_value.custom_field_id == text_custom_field.id
                   end.typed_value)
              .to eq('foo')

            expect(project.custom_field_values.find do |custom_value|
                     custom_value.custom_field_id == bool_custom_field.id
                   end.typed_value)
              .to be_truthy
          end
        end
      end
    end
  end

  context 'when creating with custom field values' do
    let(:project) do
      create(:project, custom_field_values: {
               text_custom_field.id => 'foo',
               bool_custom_field.id => true
             })
    end

    it 'saves the custom field values properly' do
      expect(project.custom_value_for(text_custom_field).typed_value)
        .to eq('foo')
      expect(project.custom_value_for(bool_custom_field).typed_value)
        .to be_truthy
    end

    it 'enables fields with provided values and disables fields with none' do
      # list_custom_field is not provided, thus it should not be enabled
      expect(project.project_custom_field_project_mappings.pluck(:custom_field_id))
          .to contain_exactly(text_custom_field.id, bool_custom_field.id)
      expect(project.project_custom_fields)
        .to contain_exactly(text_custom_field, bool_custom_field)
    end

    context 'with correct validation' do
      let(:another_section) { create(:project_custom_field_section) }

      let!(:required_text_custom_field) do
        create(:text_project_custom_field,
               is_required: true,
               project_custom_field_section: another_section)
      end

      it 'validates all custom values if not scoped to a section' do
        project = build(:project, custom_field_values: {
                          text_custom_field.id => 'foo',
                          bool_custom_field.id => true
                        })

        expect(project).not_to be_valid

        expect { project.save! }.to raise_error(ActiveRecord::RecordInvalid)
      end

      it 'rejects section validation scoping for project creation' do
        project = build(:project, custom_field_values: {
                                    text_custom_field.id => 'foo',
                                    bool_custom_field.id => true
                                  },
                                  _limit_custom_fields_validation_to_section_id: section.id)

        expect { project.save! }.to raise_error(ArgumentError)
      end

      it 'temporarly validates only custom values of a section if section scope is provided while updating' do
        project = create(:project, custom_field_values: {
                           text_custom_field.id => 'foo',
                           bool_custom_field.id => true,
                           required_text_custom_field.id => 'bar'
                         })

        expect(project).to be_valid

        # after a project is created, a new required custom field is added
        # which gets automatically activated for all projects
        create(:text_project_custom_field,
               is_required: true,
               project_custom_field_section: another_section)

        # thus, the project is invalid in total
        expect(project.reload).not_to be_valid
        expect { project.save! }.to raise_error(ActiveRecord::RecordInvalid)

        # but we still want to allow updating other sections without invalid required custom field values
        # by limiting the validation scope to a section temporarily
        project._limit_custom_fields_validation_to_section_id = section.id

        expect(project).to be_valid

        expect { project.save! }.not_to raise_error

        # section scope is resetted after each update
        expect { project.save! }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end
  end

  context 'when updating with custom field values' do
    let(:project) { create(:project) }

    shared_examples 'implicitly enabled and saved custom values' do
      it 'enables fields with provided values' do
        # list_custom_field is not provided, thus it should not be enabled
        expect(project.project_custom_field_project_mappings.pluck(:custom_field_id))
            .to contain_exactly(text_custom_field.id, bool_custom_field.id)
        expect(project.project_custom_fields)
          .to contain_exactly(text_custom_field, bool_custom_field)
      end

      it 'saves the custom field values properly' do
        expect(project.custom_value_for(text_custom_field).typed_value)
          .to eq('foo')
        expect(project.custom_value_for(bool_custom_field).typed_value)
          .to be_truthy
      end
    end

    context 'with #update method' do
      before do
        project.update(custom_field_values: {
                         text_custom_field.id => 'foo',
                         bool_custom_field.id => true
                       })
      end

      it_behaves_like 'implicitly enabled and saved custom values'
    end

    context 'with #update! method' do
      before do
        project.update!(custom_field_values: {
                          text_custom_field.id => 'foo',
                          bool_custom_field.id => true
                        })
      end

      it_behaves_like 'implicitly enabled and saved custom values'
    end

    context 'with #custom_field_values= method' do
      before do
        project.custom_field_values = {
          text_custom_field.id => 'foo',
          bool_custom_field.id => true
        }

        project.save!
      end

      it_behaves_like 'implicitly enabled and saved custom values'
    end
  end
end
