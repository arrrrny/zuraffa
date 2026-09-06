// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'form_submission.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FormSubmission _$FormSubmissionFromJson(Map<String, dynamic> json) =>
    $checkedCreate('FormSubmission', json, ($checkedConvert) {
      final val = FormSubmission(
        id: $checkedConvert('id', (v) => v as String?),
        templateId: $checkedConvert('templateId', (v) => v as String),
        inputValues: $checkedConvert(
          'inputValues',
          (v) => v as Map<String, dynamic>,
        ),
        status: $checkedConvert(
          'status',
          (v) => $enumDecode(_$FormSubmissionStatusEnumMap, v),
        ),
      );
      return val;
    });

Map<String, dynamic> _$FormSubmissionToJson(FormSubmission instance) =>
    <String, dynamic>{
      'id': instance.id,
      'templateId': instance.templateId,
      'inputValues': instance.inputValues,
      'status': _$FormSubmissionStatusEnumMap[instance.status]!,
    };

const _$FormSubmissionStatusEnumMap = {
  FormSubmissionStatus.draft: 'draft',
  FormSubmissionStatus.submitted: 'submitted',
  FormSubmissionStatus.approved: 'approved',
  FormSubmissionStatus.rejected: 'rejected',
};
