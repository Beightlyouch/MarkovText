require 'natto'
require 'pp'
require 'enumerator'
require 'matrix'
require 'logger'
require 'byebug'
require 'pry'

#グローバル変数 ハッシュ
$markov_model = {}
# ----------------形態素解析
# ----------------辞書的なものの作成
def parse_text(text)
    #Natto::Mecabのオブジェクト作成
    mecab = Natto::MeCab.new
    #strip: 空白を削除する
    text = text.strip
    # 形態素解析したデータを配列に分けて突っ込む
    # 先頭にBEGIN、最後にENDを追加？
    data = ["BEGIN","BEGIN"]

    #形態素解析データ
    parsed_text = mecab.parse(text)
    parse_text do |a|
        #surface: 単語
        if a.surface != nil
            puts a.feature
            data << a.surface
        end
        #"BEGIN", "BEGIN", "****", "****", ...
        puts data
    end
    #"BEGIN", "BEGIN", "****", "****", ..., "END"
    data << "END"
    #我は海の子
    #("BEGIN", "BEGIN", "我"), ("我", "は", "海"), ("は", "海", "の"), ("海", "の", "子"), ("の", "子", "END")
    data.each_cons(3).each do |a|
        #("BEGIN", "BEGIN", "****"), ("****", "****", "****"), ....のそれぞれの組について
        #suffix => 組の最後の要素
        #prefix => 組の最初、２番目
        suffix = a.pop
        prefix = a
        #prefixが未定義なら初期化
        $markov_model[prefix] ||= []
        #???
        $markov_model[prefix] << suffix
    end
end

#括弧を１単語とする
def parse_text_array(text)
    nm = Natto::MeCab.new
    # 形態素解析したデータを配列に分けて突っ込む
    # 先頭にBEGIN、最後にENDを追加
    data = ["BEGIN","BEGIN"]

    #enum_parse
    # -F => node-format option to customize the resulting MeCabNode feature attribute to extract:
    # %m => morpheme surface 
    nm = Natto::MeCab.new('-F%m')
    pattern = /「.*?」|＜.*?＞|\(.*?\)|【.*?】|≪.*?≫|（.*?）|『.*?』|“.*?”/

    # boundary_constraintsでパターンに当てはまるものは一つの単語として扱える

    if text.match(pattern)
        #enum_parse => 出力を加工したい場合や、別のオブジェクトに値を格納したい場合(parseの代わり)
        #boundary_constraints => 指定された形態素境界にマッチするものは、一つの形態素として扱って解析するようになる
        enum = nm.enum_parse(text, boundary_constraints: pattern)
    else
        enum = nm.enum_parse(text)
    end

    enum.each do |n|
        #n => #<Natto::MeCabNode:0x00007fdb62107b48 @pointer=#<FFI::Pointer address=0x000000010db410e0>, stat=0, @surface="我", @feature="名詞,一般,*,*,*,*,我,ワガ,ワガ">
        #bos/eos => beginning/end of sentence
        #is_bos?って結局なんなんだろう
        data << n.feature if !(n.is_bos? || n.is_eos?)
    end

    data << "END"
    #2語をkeyとして続く単語をvalueとしてハッシュに入れる?
    data.each_cons(3).each do |a|
        suffix = a.pop
        prefix = a
        #最初だけここを使う？
        $markov_model[prefix] ||= []
        #バリュー = [] にsuffixを加える
        $markov_model[prefix] << suffix
    end
end

# ----------------マルコフ連鎖
def markov()
    # ランダムインスタンスの生成
    random = Random.new
    # スタートは begin,beginから
    prefix = ["BEGIN","BEGIN"]
    ret = ""
    $indexes = []
    #ENDまでループする
    loop {
        #始まりの候補の数
        n = $markov_model[prefix].length
        prefix = [prefix[1] , $markov_model[prefix][random.rand(0..n-1)]]
        #初回 => prefix = ["BEGIN", "今回"]
        #2回 => ["今回", "#{今回をprefixとしたランダムな値}"]
        #これをENDまで
        if prefix[0] != "BEGIN"
          # ret = ret + prefix[0]
          ret += prefix[0]
        end
        if $markov_model[prefix].last == "END"
            ret += prefix[1]
            break
        end
    }
    return ret
end

=begin
# cos類似度の計算
def calc_score(str1,str2)
  vector = []
  vector1 = []
  vector2 = []
  frag_vector1 = []
  frag_vector2 = []

    mecab = Natto::MeCab.new

    mecab.parse(str1) do |a|
        if a.surface != nil
            vector1 << a.surface
        end
    end

    mecab.parse(str2) do |a|
        if a.surface != nil
            vector2 << a.surface
        end
    end

  vector += vector1
  vector += vector2

  vector.uniq!.delete("")
  vector1.delete("")
  vector.delete("")
  vector2.delete("")

  vector.each do |word|
    if vector1.include?(word) then
      frag_vector1.push(1)
    else
      frag_vector1.push(0)
    end

    if vector2.include?(word) then
      frag_vector2.push(1)
    else
      frag_vector2.push(0)
    end
  end

  vector1_final = Vector.elements(frag_vector1, copy = true)
  vector2_final = Vector.elements(frag_vector2, copy = true)

  return vector2_final.inner_product(vector1_final)/(vector1_final.norm() * vector2_final.norm())

end
=end
#r => 読み込みモード
File.open('python.txt',"r") do |file|
    file.each_line do |line|
        parse_text_array(line)
        $str1 = ''
        $str1 += line.to_s
    end
end

=begin
File.open('python.txt',"r") do |file|
    file.each_line do |line|
        parse_text_array(line)
        $str2 =''
        $str2 += line.to_s
    end
end
=end

count = 0
#文章の長さを指定
max = 500
min = 300

loop{ article = markov() 
  if article.length > min && article.length < max
    puts article
    count += 1
  else
    count += 1
    puts article
    puts 'ERROR'
  end
  if count >= 1 #生成したい数を指定
  break
  end
}
=begin
    count = 0
    #文章の長さを指定
    max = 600
    min = 400
    if article.length > min && article.length < max
            puts article
            puts article.length
            cos1 = calc_score(article,$str1)
            cos2 = calc_score(article,$str2)
          puts "rubyとのcos類似度:" + cos1.to_s
            puts "pythonとのcos類似度:" + cos2.to_s
            count += 1
    end
    if count >= 1 #生成したい数を指定
        break
    end
=end