$(function() {
  var list;
  for (i in moduleList)
    list += "<p>"+moduleList[i]+"</p>"
  $("#navbar").append($(list))
})