DP.showMotivation = function (state) {
  $(".motivation." + state).show();
  $(".dropdown-items").hide();
};

DP.motivationCancel = function () {
  $(".motivation").hide();
  $(".dropdown-items").show();
};
