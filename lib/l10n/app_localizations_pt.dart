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

  @override
  String get authWelcome => 'Bem-vindo de volta';

  @override
  String get authCreateAccount => 'Crie sua conta';

  @override
  String get authSubtitle => 'Entre para ver seus medicamentos.';

  @override
  String get emailLabel => 'E-mail';

  @override
  String get emailHint => 'voce@exemplo.com';

  @override
  String get passwordLabel => 'Senha';

  @override
  String get passwordHint => 'Sua senha';

  @override
  String get nameLabel => 'Nome';

  @override
  String get nameHint => 'Seu nome';

  @override
  String get signIn => 'Entrar';

  @override
  String get signUp => 'Criar conta';

  @override
  String get noAccount => 'Não tem conta? Cadastre-se';

  @override
  String get haveAccount => 'Já tem conta? Entre';

  @override
  String get authConfirmationSent =>
      'Verifique seu e-mail para confirmar sua conta.';

  @override
  String get authFillAll => 'Informe seu e-mail e senha.';

  @override
  String get signOut => 'Sair';

  @override
  String get signOutConfirm => 'Sair do Certo?';

  @override
  String get cancel => 'Cancelar';

  @override
  String get profile => 'Perfil';

  @override
  String get language => 'Idioma';

  @override
  String get languageSystem => 'Padrão do sistema';

  @override
  String get languageEnglish => 'Inglês';

  @override
  String get languagePortuguese => 'Português';

  @override
  String get notifications => 'Notificações';

  @override
  String get notificationsComingSoon =>
      'Configurações de notificações em breve';

  @override
  String get account => 'Conta';

  @override
  String get about => 'Sobre';

  @override
  String get aboutBody => 'Certo — lembretes de medicamentos descomplicados.';

  @override
  String get editName => 'Editar nome';

  @override
  String get save => 'Salvar';

  @override
  String get nameSaved => 'Nome salvo ✓';

  @override
  String get medicationName => 'Nome do medicamento';

  @override
  String get medicationNameHint => 'ex.: Amoxicilina 500mg';

  @override
  String get dosageHint => 'ex.: 1 comprimido';

  @override
  String get instruction => 'Instrução';

  @override
  String get instructionHint => 'ex.: Após a refeição';

  @override
  String get category => 'Categoria';

  @override
  String get categoryHint => 'ex.: Antibiótico · Comprimido oral';

  @override
  String get notesHint => 'Observações opcionais';

  @override
  String get times => 'Horários';

  @override
  String get addTime => 'Adicionar horário';

  @override
  String get pillColor => 'Cor do comprimido';

  @override
  String get saveMedication => 'Salvar medicamento';

  @override
  String get medicationSaved => 'Medicamento salvo ✓';

  @override
  String get fillRequired => 'Informe o nome do medicamento.';

  @override
  String get addAtLeastOneTime => 'Adicione pelo menos um horário.';

  @override
  String get missedDose => 'Medicamento em atraso';

  @override
  String wasDueAt(String time) {
    return 'era para $time';
  }

  @override
  String get noMedicationsTitle => 'Nenhum medicamento ainda';

  @override
  String get noMedicationsBody =>
      'Adicione seu primeiro medicamento para começar.';

  @override
  String get noActiveMedicationsTitle => 'Nenhum medicamento ativo';

  @override
  String get noActiveMedicationsBody =>
      'Os medicamentos que você toma agora aparecerão aqui.';

  @override
  String get emptyFilterTitle => 'Nada por aqui';

  @override
  String get emptyFilterBody => 'Nenhum medicamento corresponde a este filtro.';

  @override
  String get noScheduleTitle => 'Nada agendado';

  @override
  String get noScheduleBody => 'Nenhum medicamento agendado para este dia.';
}
