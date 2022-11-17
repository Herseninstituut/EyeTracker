function [dblRoundness,dblArea,vecCentroid,imBW] = getApproxPupil(gMatVid,dblPupilT,objSE,vecPrevLoc,boolLowest)
	
	%% take trough in histogram closest to requested pupil threshold as luminance cut-off
	[vecHist,vecEdges] = histcounts(gMatVid(:),128);
	vecHistSmooth = conv(vecHist(2:(end-1)),normpdf(-2:2),'same');
	vecHSD = diff(vecHistSmooth);
	[dummy,vecTroughs] = findpeaks(-vecHistSmooth);
	vecLumTroughs = vecEdges(vecTroughs+1);
	[dblDiff,intIdx] = min(abs(vecLumTroughs-dblPupilT));
	dblHistPupilT = vecLumTroughs(intIdx)+1;
	if dblDiff > 5
		dblNewPupilT = dblPupilT;
	else
		dblNewPupilT = dblHistPupilT;
	end
	
	%% find areas
	gMatVidOrig = gMatVid;
	sProps = [];
	while isempty(sProps)
		%calculate pupil threshold, binarize and invert so pupil is white (<15)
		gMatVid = gMatVidOrig < dblNewPupilT;
		
		%morphological closing (dilate+erode) to remove reflection boundary
		gMatVid = imclose(gMatVid,objSE);
		
		%fill small holes
		gMatVid = imfill(gMatVid,4,'holes');
		%morphological opening (erode+dilate) to remove small connections
		gMatVid = imopen(gMatVid,objSE);
		
		%get regions of sufficient size
		imBW = gather(gMatVid);
		sCC = bwconncomp(imBW, 4);
		sProps = regionprops(sCC, 'Centroid', 'Area','Perimeter','MajorAxisLength','MinorAxisLength');
		
		%increment threshold if nothing is found
		if dblNewPupilT < 200 && boolLowest
			dblNewPupilT = dblNewPupilT + 2;
		else
			break;
		end
	end
	if isempty(sProps)
		dblRoundness = nan;
		dblArea = 0;
		vecCentroid = vecPrevLoc(1:2);
		imBW = false(size(gMatVid));
		return;
	end
	%get area properties
	vecArea = [sProps.Area];
	vecMajAx = [sProps.MajorAxisLength];
	vecMinAx = [sProps.MinorAxisLength];
	vecPerimeter = [sProps.Perimeter];
	matCentroids = cell2mat({sProps.Centroid}')';
	
	%what is area to perimeter ratio?
	vecAreaToPerim = vecArea./vecPerimeter;
	%what would it be if it were a circle?
	vecCircAreaToPerim = (vecMinAx+vecMajAx)/8;
	vecRoundness = vecAreaToPerim ./ vecCircAreaToPerim;
	
	%choose most likely object
	vecDist = sqrt(sum(bsxfun(@minus,matCentroids,flat(vecPrevLoc(1:2))).^2,1));
	dblSd = sqrt(sum(size(imBW).^2));
	vecProbChoose = 1 - normcdf(vecDist,0,dblSd/2) + normcdf(-vecDist,0,dblSd/2);
	
	[dblProb,intUseObject]=max(vecRoundness .* vecProbChoose);
	dblRoundness = vecRoundness(intUseObject);
	dblArea = vecArea(intUseObject);
	vecCentroid = matCentroids(:,intUseObject);
	
end
%}