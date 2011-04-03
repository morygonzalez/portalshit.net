#!/usr/bin/env ruby
#-*- coding: utf-8 -*-

require "rubygems"
require "rspec"
require File.dirname(__FILE__) + "/set_categories"

describe SetCategory, "SetCategory" do
  subject { SetCategory.new }
  subject.stub(:load_logs).and_return {
    <<EOD
-
  id: 2
  name: "チーズと小芋定食"
  href: "http://"
  category: "WWW"
  tag: "2ch"
  comment: "<p>　いつもの日課、２ちゃんねるを閲覧していたらこんなもの発見。</p>\r\n\r\n<img src=\"./resources/prefaich.jpg\" width=\"512\"  height=\"430\" alt=\"万博と弁当\" />\r\n\r\n<p>　ものすごく悲しいじゃないか。そういえば２ヶ月前、愛知万博への弁当持ち込み禁止がニュースで話題になっていたことを思い出す。</p><!--more-->\r\n\r\n<p>　気になったので調べてみたら、<a target=\"_blank\" href=\"http://blog.livedoor.jp/nekokix/archives/17373489.html\">こんなの</a>を発見。愛知万博に対する怒りが込み上げてきた。なんだこのチーズと小芋定食3000円てのは？　愛知県民やることきたな過ぎと憤慨してしまった。だいたい、ＡＡの警備員のおじさんの名古屋弁がひどい。</p>\r\n\r\n<p>　そこで“チーズと小芋定食”でグーグル検索してみたら、<a target=\"_blank\" href=\"http://www.hinalog.com/archives/000379.php\">こんなの</a>発見。なぁんだ、２ちゃんねらが一部の高い飲食店のことを取り上げて騒いでただけか、と一安心する。チーズと小芋定食は２ちゃんねらがねつ造して作り上げた定食のようだ。</p>\r\n\r\n<p>　しかし一方で確かに愛知万博にはボッタクリとしか思えない飲食店もあるようで、例えばこれ<br>\r\n<a target=\"_blank\" class=\"ref\" href=\"http://www.chitaka.co.jp/30ff/33depo/33mitsui.html\">http://www.chitaka.co.jp/30ff/33depo/33mitsui.html</a><br>\r\n<a target=\"_blank\" class=\"ref\" href=\"http://www.chitaka.co.jp/10topix/expo2005_02.html\">http://www.chitaka.co.jp/10topix/expo2005_02.html</a><br>\r\nなんかひどい。二つともchitaka.co.jpというドメインのもので、同じ会社のサイトだ。上のURLではカレーは390円だが、万博会場で買うと（下のリンク）1000円になっている。万博仕様に高級な食材を使っているとは考えにくいし、そうだとしたらぼったくりもいいとこだ。</p>\r\n\r\n<p>　結局、万博は死ぬほど並ばなきゃいけないみたいだし、クソ暑いなか行ってられるかよ、って感じです >な。入場料も五千円近くするみたいだし。</p>\r\n\r\n<p>　ところで、↓の一連の流れが面白かった。俺はアホなので、60を読んですっかりうるうるしてしまったのだけど、62の突っ込みが的確過ぎて良いです。モナーが泣いているのがまた良い（笑</p>\r\n\r\n<img src=\"./resources/predaich2.jpg\" width=\"512\"  height=\"572\" alt=\"万博と弁当２\" />\r\n\r\n<p>　いまどきこういう家族なんてなかなかいないんだろうけど、うちの母親なんかケチで子どもの頃から我が家は死ぬほど貧乏だと（まぁ実際貧乏なんですが）叩き込まれてきた俺としては、こういうのを見るとうるうるせずにはいられないのでありました。</p>" 
  date: "2005-05-31 13:50:49"
  mod: "2009-07-31 16:36:12"
  draft: 0
  ping_uri: ""
EOD
  }

  context "load_logs" do
    it "ymlを読み込めていること" do
      subject.load_logs.should be_true
    end
    
    it "配列であること" do
      subject.load_logs.should be_kind_of(Array)
    end
  end
  
  context "list_categories" do        
    it "一つ以上の値を持つこと" do
      subject.list_categories.size.should have_at_least(1).item
    end
    
    it "配列の中身が空でないこと" do
      subject.list_categories.should_not include("")
    end
  end

  context "make_hash" do
    it "配列を渡されたときハッシュを返すこと" do
      subject.make_hash([]).should be_kind_of(Hash)
    end
  end
  
  context "insert_categories" do
    it "trueを返すこと" do
      subject.insert_categories.should be_true
    end
  end
end
