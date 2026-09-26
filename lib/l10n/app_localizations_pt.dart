// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get onboardingHeadline => 'Seu medicamento,\ndescomplicado.';

  @override
  String get onboardingSubtitle =>
      'Orientação clara. Identificação fácil.\nFeito para todos.';

  @override
  String get getStarted => 'Começar';

  @override
  String greeting(String name) {
    return 'Bom dia, $name';
  }

  @override
  String get timeForMedication => 'Está na hora do seu medicamento';

  @override
  String medicationCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count medicamentos',
      one: '$count medicamento',
    );
    return '$_temp0';
  }

  @override
  String get today => 'Hoje';

  @override
  String get settings => 'Configurações';

  @override
  String get voiceComingSoon => 'Assistente de voz em breve';

  @override
  String get cameraComingSoon => 'Identificação por câmera em breve';

  @override
  String get manualComingSoon => 'Cadastro manual em breve';

  @override
  String get editMedication => 'Editar medicamento';

  @override
  String get home => 'Início';

  @override
  String get meds => 'Remédios';

  @override
  String get schedule => 'Agenda';

  @override
  String get caregiver => 'Cuidador';

  @override
  String get myMedications => 'Meus medicamentos';

  @override
  String get filterAll => 'Todos';

  @override
  String get filterActive => 'Ativos';

  @override
  String get filterPaused => 'Pausados';

  @override
  String get filterFinished => 'Concluídos';

  @override
  String get addMedication => 'Adicionar medicamento';

  @override
  String get scanPackage => 'Escanear embalagem';

  @override
  String get scanPackageSubtitle => 'Use a câmera para identificar';

  @override
  String get addManually => 'Adicionar manualmente';

  @override
  String get addManuallySubtitle => 'Insira as informações você mesmo';

  @override
  String get recent => 'Recentes';

  @override
  String get medicationDetail => 'Detalhes do medicamento';

  @override
  String get medicationNotFound => 'Medicamento não encontrado';

  @override
  String get dosage => 'Dose';

  @override
  String takeDosage(String dosage) {
    return 'Tomar $dosage';
  }

  @override
  String get scheduleLabel => 'Horários';

  @override
  String get started => 'Início';

  @override
  String get notes => 'Observações';

  @override
  String get markAsTaken => 'Marcar como tomado';

  @override
  String get taken => 'Tomado';

  @override
  String get markedAsTaken => 'Marcado como tomado ✓';

  @override
  String get morning => 'Manhã';

  @override
  String get afternoon => 'Tarde';

  @override
  String get evening => 'Noite';

  @override
  String get caregiverSupport => 'Suporte do cuidador';

  @override
  String get caregiverBody =>
      'Convide um familiar ou equipe de cuidados para ajudar você a manter seus medicamentos em dia. Este recurso estará disponível em breve.';

  @override
  String get alarmRinging => 'ALARME DE MEDICAMENTO · TOCANDO';

  @override
  String get alarmTitle => 'Hora de tomar seu medicamento';

  @override
  String scheduledFor(String time) {
    return 'Agendado para $time';
  }

  @override
  String get takeAfterBreakfast => 'Tomar após o café da manhã';

  @override
  String swallowWithWater(String dosage) {
    return 'Engula $dosage com água';
  }

  @override
  String get alarmSoundPlaying => 'O som do alarme tocará até você responder';

  @override
  String get snooze => 'Adiar 10 minutos';

  @override
  String get snoozed => 'Adiado por 10 minutos';

  @override
  String get addedToday => 'Adicionado hoje';

  @override
  String get addedYesterday => 'Adicionado ontem';

  @override
  String addedDaysAgo(int count) {
    return 'Adicionado há $count dias';
  }
}
