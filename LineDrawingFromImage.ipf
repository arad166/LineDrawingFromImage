#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

Function/WAVE ConvertImageToGrayscale(imageName)
    String imageName
    Wave/Z rgb = $imageName
    if (!WaveExists(rgb))
        Abort "指定された画像Wave '" + imageName + "' が存在しません。"
    endif

    Variable width = DimSize(rgb, 0)
    Variable height = DimSize(rgb, 1)

    Make/N=(width, height)/O gray
    gray = 0.2989 * rgb[p][q][0] + 0.5870 * rgb[p][q][1] + 0.1140 * rgb[p][q][2]
    Return gray
End



Function SobelEdge(gray)
    Wave gray
    
    Variable rows = DimSize(gray, 0)
    Variable cols = DimSize(gray, 1)

    Make/O/N=(rows, cols) gx, gy, grad
    Make/O/N=9 sobelX = {-1,0,1,-2,0,2,-1,0,1}
    Make/O/N=9 sobelY = {-1,-2,-1,0,0,0,1,2,1}

    Variable i, j, x, y
    Variable sumX, sumY, idx

    for(i=1; i<rows-1; i+=1)
        for(j=1; j<cols-1; j+=1)
            sumX = 0
            sumY = 0
            for(x=-1; x<=1; x+=1)
                for(y=-1; y<=1; y+=1)
                    idx = (x+1)*3 + (y+1) // カーネルの位置インデックス
                    sumX += gray[i+x][j+y] * sobelX[idx]
                    sumY += gray[i+x][j+y] * sobelY[idx]
                endfor
            endfor
            gx[i][j] = sumX
            gy[i][j] = sumY
            grad[i][j] = sqrt(sumX^2 + sumY^2)
        endfor
    endfor

End


Function ExtractCoordsFromGrad(grad, threshold)
    Wave grad
    Variable threshold

    Variable rows = DimSize(grad, 0)
    Variable cols = DimSize(grad, 1)
    Variable i, j, count = 0

    // 点数をまず数える
    for(i=0; i<rows; i+=1)
        for(j=0; j<cols; j+=1)
            if(grad[i][j] > threshold)
                count += 1
            endif
        endfor
    endfor

    // Wave を作成
    Make /O/N=(count) x_coord, y_coord
    count = 0
    for(i=0; i<rows; i+=1)
        for(j=0; j<cols; j+=1)
            if(grad[i][j] > threshold)
                x_coord[count] = j
                y_coord[count] = i
                count += 1
            endif
        endfor
    endfor
End


Function CountGradPointsAboveThreshold(grad, threshold)
    Wave grad
    Variable threshold

    Variable rows = DimSize(grad, 0)
    Variable cols = DimSize(grad, 1)
    Variable i, j, count = 0

    for(i=0; i<rows; i+=1)
        for(j=0; j<cols; j+=1)
            if(grad[i][j] > threshold)
                count += 1
            endif
        endfor
    endfor
    return count
End


Function ExtractEdgeCoordsAutoThreshold(grad, maxPoints)
    Wave grad
    Variable maxPoints


    Variable rows = DimSize(grad, 0)
    Variable cols = DimSize(grad, 1)
    Variable i, j, count
    Variable left = 0, right = 1e6  // threshold の探索範囲
    Variable mid, bestThreshold = 0

    // 最大の勾配値を探して右端にする（初期化）
    Variable maxVal = -1e30
    for(i=0; i<rows; i+=1)
        for(j=0; j<cols; j+=1)
            if(grad[i][j] > maxVal)
                maxVal = grad[i][j]
            endif
        endfor
    endfor
    right = maxVal

    // 二分探索（精度優先：20回でほぼ十分）
    Variable iter
    for(iter=0; iter<20; iter+=1)
        mid = (left + right) / 2
        count = CountGradPointsAboveThreshold(grad, mid)

        if(count > maxPoints)
            left = mid   // 点が多すぎる → threshold を上げる
        else
            bestThreshold = mid
            right = mid  // もっと選別できるか試す
        endif
    endfor

    Print "Auto-threshold used: ", bestThreshold
    Print "Number of points: ", CountGradPointsAboveThreshold(grad, bestThreshold)

    // 実際の座標抽出
    ExtractCoordsFromGrad(grad, bestThreshold)
End


Function NearestNeighborTSP(x_coord, y_coord)
    Wave x_coord, y_coord
    Variable N = DimSize(x_coord, 0)

    Make/O/N=(N) visited
    visited = 0

    Make/O/N=(N) x_sorted, y_sorted

    Variable current = 0
    visited[current] = 1
    x_sorted[0] = x_coord[current]
    y_sorted[0] = y_coord[current]

    Variable i, j
    Variable nearest = -1
    Variable minDist, dist
    Variable count

    for(count=1; count<N; count+=1)
        minDist = 1e30
        nearest = -1
        for(j=0; j<N; j+=1)
            if(visited[j] == 0)
                dist = sqrt((x_coord[j]-x_coord[current])^2 + (y_coord[j]-y_coord[current])^2)
                if(dist < minDist)
                    minDist = dist
                    nearest = j
                endif
            endif
        endfor
        if(nearest < 0)
            break
        endif
        visited[nearest] = 1
        x_sorted[count] = x_coord[nearest]
        y_sorted[count] = y_coord[nearest]
        current = nearest
    endfor

End

Function RemoveRandomPointsUntilThreshold(x_coord, y_coord, threshold)
    Wave x_coord, y_coord
    Variable threshold

    Variable N = numpnts(x_coord)
    if (N != numpnts(y_coord))
        Abort "x_coordとy_coordのサイズが一致していません。"
    endif

    Variable i, idx, removeCount
    Make/N=(N) /FREE indices = p

    do
        N = numpnts(x_coord)
        if (N <= threshold)
            break
        endif

        // ランダムなインデックスを1つ選ぶ
        idx = floor((enoise(1) + 1) / 2 * N)   // enoise(1)は[-1,1)、範囲を[0,1)にスケーリング
        DeletePoints idx, 1, x_coord
        DeletePoints idx, 1, y_coord

    while (1)

End

Function Main(imageName, edgeMaxCount, finalCount)
    String imageName
    Variable edgeMaxCount, finalCount
    
    Print ">>> グレースケール変換を開始..."
    Wave gray = ConvertImageToGrayscale(imageName)

    Print ">>> Sobelフィルタによるエッジ検出を実行中..."
    SobelEdge(gray)

    Print ">>> エッジ強度から座標を抽出中..."
    Wave grad // SobelEdge で作成された grad を参照
    ExtractEdgeCoordsAutoThreshold(grad, edgeMaxCount)
    Wave x_coord, y_coord

    Print ">>> 抽出されたエッジ点数: ", numpnts(x_coord)
    if (numpnts(x_coord) >= 30000)
        Abort "点数が多すぎます（" + num2str(numpnts(x_coord)) + "点）。処理を中止します。"
    endif

    Print ">>> 点数制限のためランダムに間引き中..."
    RemoveRandomPointsUntilThreshold(x_coord, y_coord, finalCount)

    Print ">>> TSP（巡回セールスマン問題）の近傍貪欲法による経路計算を開始..."
    Wave x_sorted, y_sorted
    NearestNeighborTSP(x_coord, y_coord)

    Print ">>> 結果を表示中..."
    Display x_sorted vs y_sorted
    SetAxis/A/R left

    Print ">>> 完了しました。"
End