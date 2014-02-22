window.foodrank.App = function(){
  var test_keyup = function(event){
    if(event.keyCode === 13) submit_name();
  };

  var present = function(string){
    return string.length > 0;
  };

  var submit_name = function(event){
    if(event) event.preventDefault();
    var request = $('.json_input').val();
    if(present(request)){
      print_result('thinking...');
      $.getJSON('/sample.json', {request:request}, print_result);
    }else{
      print_result('please!');
    }
  };

  var print_result = function(result){
    console.log(result);
  };

  var bindUI = function(){
    $('.json_input').keyup(test_keyup);
    $('.get').click(submit_name);
  };

  var init = function(){
    bindUI();
  };

  init();
};

$(function(){
  window.app = new foodrank.App();
});