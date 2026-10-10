{ ... }:
{
  age.secrets.gh-token = {
    file = ../../secrets/gh-token.age;
    owner = "richard";
    mode = "0400";
  };
}
